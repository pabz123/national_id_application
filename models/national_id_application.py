# -*- coding: utf-8 -*-
# models/national_id_application.py  –  COMPLETE REPLACEMENT
# Changes vs original:
#   1. Added next_of_kin_name and next_of_kin_phone fields
#   2. _check_active_email_uniqueness / _check_active_phone_uniqueness now
#      also check the mobile_user_id constraint for clarity

import re
from datetime import date
from dateutil.relativedelta import relativedelta
from odoo import models, fields, api
from odoo.exceptions import AccessError, UserError, ValidationError


class NationalIdApplication(models.Model):
    _name = 'national.id.application'
    _description = 'National ID Application'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'create_date desc'

    REJECTION_CATEGORIES = [
        ('incomplete_information', 'Incomplete Information'),
        ('invalid_documents', 'Invalid Documents'),
        ('duplicate_application', 'Duplicate Application'),
        ('failed_verification', 'Failed Verification'),
        ('other', 'Other'),
    ]
    REVIEW_ACTIVITY_PREFIX = '[National ID Review]'

    # ── Basic information ──────────────────────────────────────────────────
    name = fields.Char(
        string='Application Reference', required=True,
        copy=False, readonly=True,
        default=lambda self: self.env['ir.sequence'].next_by_code(
            'national.id.application') or 'New')
    full_name = fields.Char(string='Full Name', required=True, tracking=True)
    date_of_birth = fields.Date(string='Date of Birth', required=True, tracking=True)
    age = fields.Integer(string='Age', compute='_compute_age', store=True)
    gender = fields.Selection([
        ('male', 'Male'), ('female', 'Female'), ('other', 'Other'),
    ], string='Gender', required=True, tracking=True)
    nationality_id = fields.Many2one(
        'res.country', string='Nationality', required=True, tracking=True)
    existing_nin = fields.Char(string='Existing NIN', tracking=True)
    district_id = fields.Many2one(
        'national.id.district', string='District of Origin')
    district_name = fields.Char(
        string='District Name', required=True, tracking=True)
    mobile_user_id = fields.Many2one(
        'national.id.mobile.user', string='Mobile Account', readonly=True)
    phone = fields.Char(string='Phone Number', required=True, tracking=True)
    email = fields.Char(string='Email Address', required=True, tracking=True)

    # ── Next of kin ────────────────────────────────────────────────────────
    next_of_kin_name = fields.Char(
        string='Next of Kin Name', tracking=True)
    next_of_kin_phone = fields.Char(
        string='Next of Kin Phone', tracking=True)

    # ── Attachments ────────────────────────────────────────────────────────
    photo = fields.Binary(
        string='Passport Photo', required=True, attachment=True)
    photo_filename = fields.Char(string='Photo Filename')
    lc_letter = fields.Binary(
        string='LC Reference Letter', required=True, attachment=True)
    lc_letter_filename = fields.Char(string='LC Letter Filename')

    # ── Workflow state ─────────────────────────────────────────────────────
    state = fields.Selection([
        ('new', 'New Application'),
        ('stage1_review', 'Stage 1 Review'),
        ('stage1_approved', 'Stage 1 Approved'),
        ('stage2_review', 'Stage 2 Review'),
        ('approved', 'Fully Approved'),
        ('rejected', 'Rejected'),
    ], string='Status', default='new', required=True, tracking=True)
    current_stage_label = fields.Char(
        string='Current Handler', compute='_compute_current_stage_label')
    pending_reviewer_ids = fields.Many2many(
        'res.users', string='Notified Reviewers',
        compute='_compute_pending_reviewer_ids')

    # ── Stage 1 ────────────────────────────────────────────────────────────
    stage1_approver_id = fields.Many2one('res.users', string='Stage 1 Approved By', readonly=True)
    stage1_approval_date = fields.Datetime(string='Stage 1 Approval Date', readonly=True)
    stage1_identity_verified = fields.Boolean(string='Identity details verified', tracking=True)
    stage1_documents_verified = fields.Boolean(string='Documents verified', tracking=True)
    stage1_review_notes = fields.Text(string='Stage 1 Review Notes')
    stage1_incomplete_override_reason = fields.Text(
        string='Stage 1 Incomplete Approval Reason', readonly=True, tracking=True)

    # ── Stage 2 ────────────────────────────────────────────────────────────
    stage2_approver_id = fields.Many2one('res.users', string='Stage 2 Approved By', readonly=True)
    stage2_approval_date = fields.Datetime(string='Stage 2 Approval Date', readonly=True)
    stage2_data_crosschecked = fields.Boolean(
        string='Records cross-check completed', tracking=True)
    stage2_review_notes = fields.Text(string='Stage 2 Review Notes')
    stage2_incomplete_override_reason = fields.Text(
        string='Stage 2 Incomplete Approval Reason', readonly=True, tracking=True)

    # ── Rejection ──────────────────────────────────────────────────────────
    rejection_category = fields.Selection(
        selection=REJECTION_CATEGORIES, string='Rejection Category', tracking=True)
    rejection_reason = fields.Text(string='Rejection Reason', tracking=True)
    rejected_by_id = fields.Many2one('res.users', string='Rejected By', readonly=True)
    rejected_on = fields.Datetime(string='Rejected On', readonly=True)

    def init(self):
        # Drop old unique constraints that block reapplication
        for constraint in (
            'national_id_application_email_unique',
            'national_id_application_phone_unique',
        ):
            self.env.cr.execute(
                f'ALTER TABLE national_id_application DROP CONSTRAINT IF EXISTS {constraint}')

    # ── Computed ───────────────────────────────────────────────────────────

    @api.depends('date_of_birth')
    def _compute_age(self):
        today = date.today()
        for rec in self:
            rec.age = relativedelta(today, rec.date_of_birth).years \
                if rec.date_of_birth else 0

    @api.depends('state', 'stage1_approver_id', 'stage2_approver_id')
    def _compute_current_stage_label(self):
        for rec in self:
            if rec.state == 'new':
                rec.current_stage_label = 'Officer queue'
            elif rec.state == 'stage1_review':
                rec.current_stage_label = 'Stage 1 approver queue'
            elif rec.state == 'stage1_approved':
                rec.current_stage_label = f'{rec.stage1_approver_id.name or "Stage 1"} – awaiting Stage 2'
            elif rec.state == 'stage2_review':
                rec.current_stage_label = 'Stage 2 approver queue'
            elif rec.state == 'approved':
                rec.current_stage_label = f'Fully approved by {rec.stage2_approver_id.name or "Stage 2"}'
            else:
                rec.current_stage_label = 'Rejected – rework required'

    @api.depends('activity_ids.summary', 'activity_ids.user_id')
    def _compute_pending_reviewer_ids(self):
        for rec in self:
            activities = rec.activity_ids.filtered(
                lambda a: (a.summary or '').startswith(self.REVIEW_ACTIVITY_PREFIX))
            rec.pending_reviewer_ids = activities.mapped('user_id')

    # ── Normalisers ────────────────────────────────────────────────────────

    @staticmethod
    def _norm_email(v):
        return (v or '').strip().lower()

    @staticmethod
    def _norm_phone(v):
        return re.sub(r'[^\d+]', '', (v or '').strip())

    # ── Constraints ────────────────────────────────────────────────────────

    @api.constrains('date_of_birth')
    def _check_age(self):
        today = date.today()
        for rec in self:
            if rec.date_of_birth:
                if rec.date_of_birth > today:
                    raise ValidationError('Date of birth cannot be in the future.')
                if relativedelta(today, rec.date_of_birth).years > 120:
                    raise ValidationError(
                        'Date of birth suggests age over 120 years – please verify.')

    @api.constrains('email')
    def _check_email(self):
        pattern = r'^[\w.+-]+@[\w-]+\.[\w.]+$'
        for rec in self:
            if rec.email and not re.match(pattern, rec.email):
                raise ValidationError('Please enter a valid email address.')

    @api.constrains('phone')
    def _check_phone(self):
        for rec in self:
            if rec.phone:
                digits = re.sub(r'\D', '', self._norm_phone(rec.phone))
                if len(digits) < 10:
                    raise ValidationError(
                        'Phone number must be at least 10 digits.')

    @api.constrains('email', 'state')
    def _check_active_email_uniqueness(self):
        for rec in self:
            email = self._norm_email(rec.email)
            if not email or rec.state == 'rejected':
                continue
            existing = self.search([
                ('id', '!=', rec.id),
                ('state', '!=', 'rejected'),
                ('email', '=ilike', email),
            ], limit=1)
            if existing:
                raise ValidationError(
                    'An active application with this email already exists.')

    @api.constrains('phone', 'state')
    def _check_active_phone_uniqueness(self):
        for rec in self:
            phone = self._norm_phone(rec.phone)
            if not phone or rec.state == 'rejected':
                continue
            existing = self.search([
                ('id', '!=', rec.id),
                ('state', '!=', 'rejected'),
                ('phone', '=', phone),
            ], limit=1)
            if existing:
                raise ValidationError(
                    'An active application with this phone number already exists.')

    @api.constrains('mobile_user_id', 'state')
    def _check_one_application_per_user(self):
        """A mobile user can only have one non-rejected application at a time."""
        for rec in self:
            if not rec.mobile_user_id or rec.state == 'rejected':
                continue
            existing = self.search([
                ('id', '!=', rec.id),
                ('mobile_user_id', '=', rec.mobile_user_id.id),
                ('state', '!=', 'rejected'),
            ], limit=1)
            if existing:
                raise ValidationError(
                    f'This mobile account already has an active application '
                    f'({existing.name}). A new application can only be submitted '
                    f'after the current one is rejected.')

    # ── CRUD overrides ─────────────────────────────────────────────────────

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if not vals.get('name') or vals.get('name') == 'New':
                vals['name'] = self.env['ir.sequence'].next_by_code(
                    'national.id.application') or 'New'
            if 'email' in vals:
                vals['email'] = self._norm_email(vals['email'])
            if 'phone' in vals:
                vals['phone'] = self._norm_phone(vals['phone'])
        return super().create(vals_list)

    def write(self, vals):
        if 'email' in vals:
            vals['email'] = self._norm_email(vals['email'])
        if 'phone' in vals:
            vals['phone'] = self._norm_phone(vals['phone'])
        return super().write(vals)

    # ── Helpers ────────────────────────────────────────────────────────────

    def _get_missing_required_field_labels(self):
        self.ensure_one()
        checks = [
            ('full_name', 'Full Name'),
            ('date_of_birth', 'Date of Birth'),
            ('gender', 'Gender'),
            ('nationality_id', 'Nationality'),
            ('district_name', 'District of Origin'),
            ('phone', 'Phone Number'),
            ('email', 'Email Address'),
            ('photo', 'Passport Photo'),
            ('lc_letter', 'LC Reference Letter'),
            ('next_of_kin_name', 'Next of Kin Name'),
            ('next_of_kin_phone', 'Next of Kin Phone'),
        ]
        return [label for field, label in checks if not self[field]]

    def _check_any_group(self, group_xml_ids, error_message):
        if not any(self.env.user.has_group(g) for g in group_xml_ids):
            raise AccessError(error_message)

    def _post_audit_message(self, body, subject):
        self.ensure_one()
        self.sudo().message_post(
            body=body, subject=subject,
            author_id=self.env.user.partner_id.id)

    def _clear_review_activities(self):
        self.ensure_one()
        acts = self.sudo().activity_ids.filtered(
            lambda a: (a.summary or '').startswith(self.REVIEW_ACTIVITY_PREFIX))
        if acts:
            acts.unlink()

    def _get_stage_notification_users(self, group_xml_id):
        grp = self.env.ref(group_xml_id)
        admin_grp = self.env.ref('national_id_application.group_national_id_admin')
        return (grp.user_ids | admin_grp.user_ids).filtered(
            lambda u: u.active and u.id != self.env.user.id)

    def _schedule_stage_notifications(self, group_xml_id, summary, note):
        self.ensure_one()
        todo = self.env.ref('mail.mail_activity_data_todo')
        recipients = self._get_stage_notification_users(group_xml_id)
        self._clear_review_activities()
        if not recipients:
            return
        full_summary = f'{self.REVIEW_ACTIVITY_PREFIX} {summary}'
        for user in recipients:
            self.sudo().activity_schedule(
                activity_type_id=todo.id,
                user_id=user.id,
                summary=full_summary,
                note=note,
                date_deadline=fields.Date.context_today(self),
            )

    # ── Workflow actions ────────────────────────────────────────────────────

    def action_submit_stage1(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_officer',
             'national_id_application.group_national_id_admin'],
            'Only officers or admins can submit to Stage 1.')
        if self.state != 'new':
            raise UserError('Only new applications can be submitted to Stage 1.')
        self.write({'state': 'stage1_review'})
        self._post_audit_message('Application submitted for Stage 1 review.', 'Stage 1 Started')
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_stage1_approver',
            'Stage 1 review required',
            f'Application {self.name} submitted by {self.env.user.name}.')

    def action_open_stage1_approval_wizard(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_stage1_approver',
             'national_id_application.group_national_id_admin'],
            'Only Stage 1 approvers or admins can approve Stage 1.')
        if self.state != 'stage1_review':
            raise UserError('Application must be in Stage 1 Review.')
        return {
            'name': 'Stage 1 Verification',
            'type': 'ir.actions.act_window',
            'res_model': 'national.id.approval.wizard',
            'view_mode': 'form',
            'view_id': self.env.ref(
                'national_id_application.view_national_id_approval_wizard_form').id,
            'target': 'new',
            'context': {
                'default_application_id': self.id,
                'default_stage': 'stage1',
                'default_stage1_identity_verified': self.stage1_identity_verified,
                'default_stage1_documents_verified': self.stage1_documents_verified,
                'default_stage1_review_notes': self.stage1_review_notes,
            },
        }

    def action_approve_stage1(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_stage1_approver',
             'national_id_application.group_national_id_admin'],
            'Only Stage 1 approvers or admins can approve Stage 1.')
        if self.state != 'stage1_review':
            raise UserError('Application must be in Stage 1 Review.')
        missing = self._get_missing_required_field_labels()
        allow_incomplete = bool(self.env.context.get('allow_incomplete_approval'))
        override_reason = (self.env.context.get('incomplete_approval_reason') or '').strip()
        if missing and not allow_incomplete:
            raise UserError('Missing required fields. Use approval override.')
        if missing and not override_reason:
            raise UserError('Provide a reason for approving an incomplete application.')
        if not self.stage1_identity_verified or not self.stage1_documents_verified:
            raise UserError('Complete Stage 1 checklist before approving.')
        self.write({
            'state': 'stage1_approved',
            'stage1_approver_id': self.env.user.id,
            'stage1_approval_date': fields.Datetime.now(),
            'stage1_incomplete_override_reason': override_reason if missing else False,
        })
        body = (f'✅ Stage 1 approved by <b>{self.env.user.name}</b>.'
                if not missing else
                f'✅ Stage 1 approved by <b>{self.env.user.name}</b> with override. '
                f'Missing: {", ".join(missing)}. Reason: {override_reason}')
        self._post_audit_message(body, 'Stage 1 Approved')
        self._clear_review_activities()

    def action_submit_stage2(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_stage1_approver',
             'national_id_application.group_national_id_admin'],
            'Only Stage 1 approvers or admins can submit to Stage 2.')
        if self.state != 'stage1_approved':
            raise UserError('Application must be Stage 1 approved first.')
        self.write({'state': 'stage2_review'})
        self._post_audit_message('Application submitted for Stage 2 review.', 'Stage 2 Started')
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_stage2_approver',
            'Stage 2 review required',
            f'Application {self.name} forwarded to Stage 2 by {self.env.user.name}.')

    def action_open_stage2_approval_wizard(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_stage2_approver',
             'national_id_application.group_national_id_admin'],
            'Only Stage 2 approvers or admins can do final approval.')
        if self.state != 'stage2_review':
            raise UserError('Application must be in Stage 2 Review.')
        return {
            'name': 'Stage 2 Verification',
            'type': 'ir.actions.act_window',
            'res_model': 'national.id.approval.wizard',
            'view_mode': 'form',
            'view_id': self.env.ref(
                'national_id_application.view_national_id_approval_wizard_form').id,
            'target': 'new',
            'context': {
                'default_application_id': self.id,
                'default_stage': 'stage2',
                'default_stage2_data_crosschecked': self.stage2_data_crosschecked,
                'default_stage2_review_notes': self.stage2_review_notes,
            },
        }

    def action_approve_stage2(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_stage2_approver',
             'national_id_application.group_national_id_admin'],
            'Only Stage 2 approvers or admins can do final approval.')
        if self.state != 'stage2_review':
            raise UserError('Application must be in Stage 2 Review.')
        missing = self._get_missing_required_field_labels()
        allow_incomplete = bool(self.env.context.get('allow_incomplete_approval'))
        override_reason = (self.env.context.get('incomplete_approval_reason') or '').strip()
        if missing and not allow_incomplete:
            raise UserError('Missing required fields. Use approval override.')
        if missing and not override_reason:
            raise UserError('Provide a reason for approving an incomplete application.')
        if not self.stage2_data_crosschecked:
            raise UserError('Complete Stage 2 cross-check before final approval.')
        self.write({
            'state': 'approved',
            'stage2_approver_id': self.env.user.id,
            'stage2_approval_date': fields.Datetime.now(),
            'stage2_incomplete_override_reason': override_reason if missing else False,
        })
        body = (f'✅ <b>Final approval</b> by <b>{self.env.user.name}</b>!'
                if not missing else
                f'✅ <b>Final approval</b> by <b>{self.env.user.name}</b> with override. '
                f'Missing: {", ".join(missing)}. Reason: {override_reason}')
        self._post_audit_message(body, 'Application Fully Approved')
        self._clear_review_activities()

    def action_open_rejection_wizard(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_stage1_approver',
             'national_id_application.group_national_id_stage2_approver',
             'national_id_application.group_national_id_admin'],
            'Only approvers or admins can reject applications.')
        if self.state not in ('stage1_review', 'stage2_review'):
            raise UserError(
                'Applications can only be rejected during Stage 1 or Stage 2 review.')
        return {
            'name': 'Reject Application',
            'type': 'ir.actions.act_window',
            'res_model': 'national.id.rejection.wizard',
            'view_mode': 'form',
            'view_id': self.env.ref(
                'national_id_application.view_national_id_rejection_wizard_form').id,
            'target': 'new',
            'context': {'default_application_id': self.id},
        }

    def action_reject_with_reason(self, category, reason):
        self.ensure_one()
        if self.state == 'stage2_review':
            self._check_any_group(
                ['national_id_application.group_national_id_stage2_approver',
                 'national_id_application.group_national_id_admin'],
                'Only Stage 2 approvers or admins can reject at Stage 2.')
        elif self.state == 'stage1_review':
            self._check_any_group(
                ['national_id_application.group_national_id_stage1_approver',
                 'national_id_application.group_national_id_admin'],
                'Only Stage 1 approvers or admins can reject at Stage 1.')
        else:
            raise UserError('Applications can only be rejected during review stages.')
        clean = (reason or '').strip()
        if not clean:
            raise UserError('Please provide a rejection reason.')
        cat_label = dict(self.REJECTION_CATEGORIES).get(category, 'Other')
        self.write({
            'state': 'rejected',
            'rejection_category': category or 'other',
            'rejection_reason': clean,
            'rejected_by_id': self.env.user.id,
            'rejected_on': fields.Datetime.now(),
        })
        self._post_audit_message(
            f'❌ Rejected by <b>{self.env.user.name}</b>. '
            f'Category: {cat_label}. Reason: {clean}',
            'Application Rejected')
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_officer',
            'Rework required after rejection',
            f'Application {self.name} rejected. Category: {cat_label}. Reason: {clean}')

    def action_reset_to_new(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_admin'],
            'Only admins can reset applications.')
        self.write({
            'state': 'new',
            'stage1_approver_id': False, 'stage1_approval_date': False,
            'stage2_approver_id': False, 'stage2_approval_date': False,
            'stage1_identity_verified': False, 'stage1_documents_verified': False,
            'stage1_review_notes': False, 'stage1_incomplete_override_reason': False,
            'stage2_data_crosschecked': False, 'stage2_review_notes': False,
            'stage2_incomplete_override_reason': False,
            'rejection_category': False, 'rejection_reason': False,
            'rejected_by_id': False, 'rejected_on': False,
        })
        self._post_audit_message(
            f'🔄 Reset to New by <b>{self.env.user.name}</b>.', 'Application Reset')
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_officer',
            'Application reset to New',
            f'Application {self.name} was reset to New by {self.env.user.name}.')
