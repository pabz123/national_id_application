# -*- coding: utf-8 -*-
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

    # ── BASIC INFORMATION ─────────────────────────────────────
    name = fields.Char(
        string='Application Reference',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: self.env['ir.sequence'].next_by_code(
            'national.id.application') or 'New'
    )
    full_name = fields.Char(string='Full Name', required=True, tracking=True)
    date_of_birth = fields.Date(string='Date of Birth', required=True, tracking=True)
    age = fields.Integer(string='Age', compute='_compute_age', store=True)
    gender = fields.Selection([
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    ], string='Gender', required=True, tracking=True)
    nationality_id = fields.Many2one(
        'res.country', string='Nationality', required=True, tracking=True)
    existing_nin = fields.Char(
        string='Existing NIN',
        help='Fill only if renewing/replacing an existing National ID',
        tracking=True
    )
    district_id = fields.Many2one('national.id.district', string='District of Origin')
    district_name = fields.Char(
        string='District Name', required=True, tracking=True,
        help='Name of district'
    )
    mobile_user_id = fields.Many2one(
        'national.id.mobile.user', string='Mobile Account', readonly=True)
    phone = fields.Char(string='Phone Number', required=True, tracking=True)
    email = fields.Char(string='Email Address', required=True, tracking=True)

    # ── ATTACHMENTS ───────────────────────────────────────────
    photo = fields.Binary(string='Passport Photo', required=True, attachment=True)
    photo_filename = fields.Char(string='Photo Filename')
    lc_letter = fields.Binary(string='LC Reference Letter', required=True, attachment=True)
    lc_letter_filename = fields.Char(string='LC Letter Filename')

    # ── WORKFLOW STATE ────────────────────────────────────────
    state = fields.Selection([
        ('new', 'New Application'),
        ('stage1_review', 'Stage 1 Review'),
        ('stage1_approved', 'Stage 1 Approved'),
        ('stage2_review', 'Stage 2 Review'),
        ('approved', 'Fully Approved'),
        ('rejected', 'Rejected'),
    ], string='Status', default='new', required=True, tracking=True)
    current_stage_label = fields.Char(
        string='Current Handler',
        compute='_compute_current_stage_label'
    )
    pending_reviewer_ids = fields.Many2many(
        'res.users',
        string='Notified Reviewers',
        compute='_compute_pending_reviewer_ids'
    )

    # ── STAGE 1 FIELDS ────────────────────────────────────────
    stage1_approver_id = fields.Many2one(
        'res.users', string='Stage 1 Approved By', readonly=True)
    stage1_approval_date = fields.Datetime(string='Stage 1 Approval Date', readonly=True)
    stage1_identity_verified = fields.Boolean(
        string='Identity details verified', tracking=True)
    stage1_documents_verified = fields.Boolean(
        string='Documents verified', tracking=True)
    stage1_review_notes = fields.Text(string='Stage 1 Review Notes')
    stage1_incomplete_override_reason = fields.Text(
        string='Stage 1 Incomplete Approval Reason', readonly=True, tracking=True)

    # ── STAGE 2 FIELDS ────────────────────────────────────────
    stage2_approver_id = fields.Many2one(
        'res.users', string='Stage 2 Approved By', readonly=True)
    stage2_approval_date = fields.Datetime(string='Stage 2 Approval Date', readonly=True)
    stage2_data_crosschecked = fields.Boolean(
        string='Records cross-check completed', tracking=True)
    stage2_review_notes = fields.Text(string='Stage 2 Review Notes')
    stage2_incomplete_override_reason = fields.Text(
        string='Stage 2 Incomplete Approval Reason', readonly=True, tracking=True)

    # ── REJECTION FIELDS ──────────────────────────────────────
    rejection_category = fields.Selection(
        selection=REJECTION_CATEGORIES, string='Rejection Category', tracking=True)
    rejection_reason = fields.Text(string='Rejection Reason', tracking=True)
    rejected_by_id = fields.Many2one('res.users', string='Rejected By', readonly=True)
    rejected_on = fields.Datetime(string='Rejected On', readonly=True)

    def init(self):
        # Keep historical rejected records while allowing applicants to reapply.
        self.env.cr.execute(
            'ALTER TABLE national_id_application '
            'DROP CONSTRAINT IF EXISTS national_id_application_email_unique'
        )
        self.env.cr.execute(
            'ALTER TABLE national_id_application '
            'DROP CONSTRAINT IF EXISTS national_id_application_phone_unique'
        )

    # ── COMPUTED FIELDS ───────────────────────────────────────
    @api.depends('date_of_birth')
    def _compute_age(self):
        today = date.today()
        for record in self:
            if record.date_of_birth:
                record.age = relativedelta(today, record.date_of_birth).years
            else:
                record.age = 0

    @api.depends('state', 'stage1_approver_id', 'stage2_approver_id')
    def _compute_current_stage_label(self):
        for record in self:
            if record.state == 'new':
                record.current_stage_label = 'Officer queue (admin can also review)'
            elif record.state == 'stage1_review':
                record.current_stage_label = 'Stage 1 approver queue (admin can override)'
            elif record.state == 'stage1_approved':
                approver = record.stage1_approver_id.name or 'Stage 1 approver'
                record.current_stage_label = (
                    f'{approver} completed Stage 1 (awaiting Stage 2 submission)'
                )
            elif record.state == 'stage2_review':
                record.current_stage_label = 'Stage 2 approver queue (admin can override)'
            elif record.state == 'approved':
                approver = record.stage2_approver_id.name or 'Stage 2 approver'
                record.current_stage_label = f'Fully approved by {approver}'
            else:
                record.current_stage_label = 'Rejected - officer rework required'

    @api.depends('activity_ids.summary', 'activity_ids.user_id')
    def _compute_pending_reviewer_ids(self):
        for record in self:
            review_activities = record.activity_ids.filtered(
                lambda activity: (activity.summary or '').startswith(self.REVIEW_ACTIVITY_PREFIX)
            )
            record.pending_reviewer_ids = review_activities.mapped('user_id')

    # ── CONSTRAINTS ───────────────────────────────────────────
    @staticmethod
    def _normalize_email(value):
        return (value or '').strip().lower()

    @staticmethod
    def _normalize_phone(value):
        return re.sub(r'[^\d+]', '', (value or '').strip())

    @api.constrains('date_of_birth')
    def _check_age(self):
        for record in self:
            if record.date_of_birth:
                today = date.today()
                if record.date_of_birth > today:
                    raise ValidationError('Date of birth cannot be in the future!')
                age = relativedelta(today, record.date_of_birth).years
                if age > 120:
                    raise ValidationError(
                        'Please verify the date of birth. Age appears to be over 120 years.')

    @api.constrains('email')
    def _check_email(self):
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        for record in self:
            email = self._normalize_email(record.email)
            if email and not re.match(email_pattern, email):
                raise ValidationError('Please enter a valid email address.')

    @api.constrains('phone')
    def _check_phone(self):
        for record in self:
            if record.phone:
                phone_clean = self._normalize_phone(record.phone)
                digits_only = re.sub(r'\D', '', phone_clean)
                if len(digits_only) < 10:
                    raise ValidationError('Phone number must be at least 10 digits.')

    @api.constrains('email', 'state')
    def _check_active_email_uniqueness(self):
        for record in self:
            email = self._normalize_email(record.email)
            if not email or record.state == 'rejected':
                continue
            existing = self.search([
                ('id', '!=', record.id),
                ('state', '!=', 'rejected'),
                ('email', '=ilike', email),
            ], limit=1)
            if existing:
                raise ValidationError(
                    'An active application with this email already exists.'
                )

    @api.constrains('phone', 'state')
    def _check_active_phone_uniqueness(self):
        for record in self:
            phone = self._normalize_phone(record.phone)
            if not phone or record.state == 'rejected':
                continue
            existing = self.search([
                ('id', '!=', record.id),
                ('state', '!=', 'rejected'),
                ('phone', '=', phone),
            ], limit=1)
            if existing:
                raise ValidationError(
                    'An active application with this phone number already exists.'
                )

    # ── AUTO-NUMBERING ────────────────────────────────────────
    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if not vals.get('name') or vals.get('name') == 'New':
                vals['name'] = self.env['ir.sequence'].next_by_code(
                    'national.id.application') or 'New'
            if 'email' in vals:
                vals['email'] = self._normalize_email(vals.get('email'))
            if 'phone' in vals:
                vals['phone'] = self._normalize_phone(vals.get('phone'))
        return super().create(vals_list)

    def write(self, vals):
        clean_vals = dict(vals)
        if 'email' in clean_vals:
            clean_vals['email'] = self._normalize_email(clean_vals.get('email'))
        if 'phone' in clean_vals:
            clean_vals['phone'] = self._normalize_phone(clean_vals.get('phone'))
        return super().write(clean_vals)

    # ── HELPERS ───────────────────────────────────────────────
    def _get_missing_required_field_labels(self):
        self.ensure_one()
        required_checks = [
            ('full_name', 'Full Name'),
            ('date_of_birth', 'Date of Birth'),
            ('gender', 'Gender'),
            ('nationality_id', 'Nationality'),
            ('district_name', 'District of Origin'),
            ('phone', 'Phone Number'),
            ('email', 'Email Address'),
            ('photo', 'Passport Photo'),
            ('lc_letter', 'LC Reference Letter'),
        ]
        return [label for field_name, label in required_checks if not self[field_name]]

    def _check_any_group(self, group_xml_ids, error_message):
        if not any(self.env.user.has_group(group_id) for group_id in group_xml_ids):
            raise AccessError(error_message)

    def _post_audit_message(self, body, subject):
        self.ensure_one()
        author_id = self.env.user.partner_id.id
        # Use sudo so chatter logs still post when state transition removes write access.
        self.sudo().message_post(body=body, subject=subject, author_id=author_id)

    def _clear_review_activities(self):
        self.ensure_one()
        review_activities = self.sudo().activity_ids.filtered(
            lambda activity: (activity.summary or '').startswith(self.REVIEW_ACTIVITY_PREFIX)
        )
        if review_activities:
            review_activities.unlink()

    def _get_stage_notification_users(self, group_xml_id):
        stage_group = self.env.ref(group_xml_id)
        admin_group = self.env.ref('national_id_application.group_national_id_admin')
        return (stage_group.user_ids | admin_group.user_ids).filtered(
            lambda user: user.active and user.id != self.env.user.id
        )

    def _schedule_stage_notifications(self, group_xml_id, summary, note):
        self.ensure_one()
        todo_activity = self.env.ref('mail.mail_activity_data_todo')
        recipients = self._get_stage_notification_users(group_xml_id)
        self._clear_review_activities()
        if not recipients:
            return
        full_summary = f'{self.REVIEW_ACTIVITY_PREFIX} {summary}'
        for user in recipients:
            self.sudo().activity_schedule(
                activity_type_id=todo_activity.id,
                user_id=user.id,
                summary=full_summary,
                note=note,
                date_deadline=fields.Date.context_today(self),
            )

    # ── WORKFLOW METHODS ──────────────────────────────────────
    def action_submit_stage1(self):
        self.ensure_one()
        self._check_any_group(
            [
                'national_id_application.group_national_id_officer',
                'national_id_application.group_national_id_admin',
            ],
            'Only officers or National ID admins can submit to Stage 1.'
        )
        if self.state != 'new':
            raise UserError('Only new applications can be submitted to Stage 1.')
        self.write({'state': 'stage1_review'})
        self._post_audit_message(
            body='Application submitted for Stage 1 review.',
            subject='Stage 1 Review Started'
        )
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_stage1_approver',
            'Stage 1 review required',
            (
                f'Application {self.name} was submitted by {self.env.user.name}. '
                'Please review and verify Stage 1 checks.'
            ),
        )

    def action_open_stage1_approval_wizard(self):
        self.ensure_one()
        self._check_any_group(
            [
                'national_id_application.group_national_id_stage1_approver',
                'national_id_application.group_national_id_admin',
            ],
            'Only Stage 1 approvers or National ID admins can perform Stage 1 approvals.'
        )
        if self.state != 'stage1_review':
            raise UserError('Application must be in Stage 1 Review before approval.')
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
            [
                'national_id_application.group_national_id_stage1_approver',
                'national_id_application.group_national_id_admin',
            ],
            'Only Stage 1 approvers or National ID admins can perform Stage 1 approvals.'
        )
        if self.state != 'stage1_review':
            raise UserError('Application must be in Stage 1 Review before approval.')
        missing_fields = self._get_missing_required_field_labels()
        allow_incomplete = bool(self.env.context.get('allow_incomplete_approval'))
        override_reason = (self.env.context.get('incomplete_approval_reason') or '').strip()
        if missing_fields and not allow_incomplete:
            raise UserError(
                'This application has missing required fields. '
                'Use the approval override and provide a valid reason.'
            )
        if missing_fields and not override_reason:
            raise UserError(
                'Please provide a reason for approving an incomplete application.')
        if not self.stage1_identity_verified or not self.stage1_documents_verified:
            raise UserError('Complete Stage 1 verification checklist before approving.')
        self.write({
            'state': 'stage1_approved',
            'stage1_approver_id': self.env.user.id,
            'stage1_approval_date': fields.Datetime.now(),
            'stage1_incomplete_override_reason': override_reason if missing_fields else False,
        })
        body = (
            f'✅ Stage 1 approved by <b>{self.env.user.name}</b>.'
            if not missing_fields else
            f'✅ Stage 1 approved by <b>{self.env.user.name}</b> with override. '
            f'Missing: {", ".join(missing_fields)}. Reason: {override_reason}'
        )
        self._post_audit_message(body=body, subject='Stage 1 Approved')
        self._clear_review_activities()

    def action_submit_stage2(self):
        self.ensure_one()
        self._check_any_group(
            [
                'national_id_application.group_national_id_stage1_approver',
                'national_id_application.group_national_id_admin',
            ],
            'Only Stage 1 approvers or National ID admins can submit to Stage 2.'
        )
        if self.state != 'stage1_approved':
            raise UserError('Application must be Stage 1 approved first.')
        self.write({'state': 'stage2_review'})
        self._post_audit_message(
            body='Application submitted for Stage 2 review.',
            subject='Stage 2 Review Started'
        )
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_stage2_approver',
            'Stage 2 review required',
            (
                f'Application {self.name} was forwarded to Stage 2 by {self.env.user.name}. '
                'Please complete final verification.'
            ),
        )

    def action_open_stage2_approval_wizard(self):
        self.ensure_one()
        self._check_any_group(
            [
                'national_id_application.group_national_id_stage2_approver',
                'national_id_application.group_national_id_admin',
            ],
            'Only Stage 2 approvers or National ID admins can perform Stage 2 approvals.'
        )
        if self.state != 'stage2_review':
            raise UserError('Application must be in Stage 2 Review before final approval.')
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
            [
                'national_id_application.group_national_id_stage2_approver',
                'national_id_application.group_national_id_admin',
            ],
            'Only Stage 2 approvers or National ID admins can perform Stage 2 approvals.'
        )
        if self.state != 'stage2_review':
            raise UserError('Application must be in Stage 2 Review before final approval.')
        missing_fields = self._get_missing_required_field_labels()
        allow_incomplete = bool(self.env.context.get('allow_incomplete_approval'))
        override_reason = (self.env.context.get('incomplete_approval_reason') or '').strip()
        if missing_fields and not allow_incomplete:
            raise UserError(
                'This application has missing required fields. '
                'Use the approval override and provide a valid reason.'
            )
        if missing_fields and not override_reason:
            raise UserError(
                'Please provide a reason for approving an incomplete application.')
        if not self.stage2_data_crosschecked:
            raise UserError('Complete Stage 2 cross-check before final approval.')
        self.write({
            'state': 'approved',
            'stage2_approver_id': self.env.user.id,
            'stage2_approval_date': fields.Datetime.now(),
            'stage2_incomplete_override_reason': override_reason if missing_fields else False,
        })
        body = (
            f'✅ <b>Final approval</b> by <b>{self.env.user.name}</b>. '
            'Application fully approved!'
            if not missing_fields else
            f'✅ <b>Final approval</b> by <b>{self.env.user.name}</b> with override. '
            f'Missing: {", ".join(missing_fields)}. Reason: {override_reason}'
        )
        self._post_audit_message(body=body, subject='Application Fully Approved')
        self._clear_review_activities()

    def action_open_rejection_wizard(self):
        self.ensure_one()
        self._check_any_group(
            [
                'national_id_application.group_national_id_stage1_approver',
                'national_id_application.group_national_id_stage2_approver',
                'national_id_application.group_national_id_admin',
            ],
            'Only approvers or National ID admins can reject applications.'
        )
        if self.state not in ['stage1_review', 'stage2_review']:
            raise UserError(
                'Applications can only be rejected while in Stage 1 Review, '
                'or Stage 2 Review.'
            )
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
                [
                    'national_id_application.group_national_id_stage2_approver',
                    'national_id_application.group_national_id_admin',
                ],
                'Only Stage 2 approvers or National ID admins can reject at Stage 2.'
            )
        elif self.state == 'stage1_review':
            self._check_any_group(
                [
                    'national_id_application.group_national_id_stage1_approver',
                    'national_id_application.group_national_id_admin',
                ],
                'Only Stage 1 approvers or National ID admins can reject at Stage 1.'
            )
        else:
            raise UserError(
                'Applications can only be rejected while in Stage 1 Review, '
                'or Stage 2 Review.'
            )
        clean_reason = (reason or '').strip()
        if not clean_reason:
            raise UserError('Please provide a rejection reason.')
        category_label = dict(self.REJECTION_CATEGORIES).get(category, 'Other')
        self.write({
            'state': 'rejected',
            'rejection_category': category or 'other',
            'rejection_reason': clean_reason,
            'rejected_by_id': self.env.user.id,
            'rejected_on': fields.Datetime.now(),
        })
        self._post_audit_message(
            body=(
                f'❌ Application rejected by <b>{self.env.user.name}</b>. '
                f'Category: {category_label}. Reason: {clean_reason}'
            ),
            subject='Application Rejected'
        )
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_officer',
            'Rework required after rejection',
            (
                f'Application {self.name} was rejected by {self.env.user.name}. '
                f'Category: {category_label}. Reason: {clean_reason}'
            ),
        )

    def action_reset_to_new(self):
        self.ensure_one()
        self._check_any_group(
            ['national_id_application.group_national_id_admin'],
            'Only National ID admins can reset applications.'
        )
        self.write({
            'state': 'new',
            'stage1_approver_id': False,
            'stage1_approval_date': False,
            'stage2_approver_id': False,
            'stage2_approval_date': False,
            'stage1_identity_verified': False,
            'stage1_documents_verified': False,
            'stage1_review_notes': False,
            'stage1_incomplete_override_reason': False,
            'stage2_data_crosschecked': False,
            'stage2_review_notes': False,
            'stage2_incomplete_override_reason': False,
            'rejection_category': False,
            'rejection_reason': False,
            'rejected_by_id': False,
            'rejected_on': False,
        })
        self._post_audit_message(
            body=f'🔄 Application reset to New by <b>{self.env.user.name}</b>.',
            subject='Application Reset'
        )
        self._schedule_stage_notifications(
            'national_id_application.group_national_id_officer',
            'Application reset to New',
            (
                f'Application {self.name} was reset to New by {self.env.user.name}. '
                'Officer review and resubmission may be required.'
            ),
        )
