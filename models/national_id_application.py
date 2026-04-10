# -*- coding: utf-8 -*-
from odoo import models, fields, api
from odoo.exceptions import UserError, ValidationError
from datetime import date
from dateutil.relativedelta import relativedelta


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
    
    #constraints to ensure email and phone uniqueness across applications
    _sql_constraints = [
    ('email_unique', 'UNIQUE(email)', 
     'This email address is already registered!'),
    ('phone_unique', 'UNIQUE(phone)', 
     'This phone number is already registered!')
    ]   

    # ========== BASIC INFORMATION ==========
    
    name = fields.Char(
        string='Application Reference',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: self.env['ir.sequence'].next_by_code('national.id.application') or 'New'
    )
    
    full_name = fields.Char(
        string='Full Name',
        required=True,
        tracking=True
    )
    
    date_of_birth = fields.Date(
        string='Date of Birth',
        required=True,
        tracking=True
    )
    
    age = fields.Integer(
        string='Age',
        compute='_compute_age',
        store=True
    )
    
    gender = fields.Selection([
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    ], string='Gender', required=True, tracking=True)
    
    nationality_id = fields.Many2one(
        'res.country',
        string='Nationality',
        required=True,
        tracking=True
    )
    
    existing_nin = fields.Char(
        string='Existing NIN (National Identification Number)',
        help='Fill this only if you are renewing/replacing an existing National ID',
        tracking=True
    )
    
    district_id = fields.Many2one(
        'national.id.district',
        string='District of Origin',
        tracking=True
    )
    
    district_name = fields.Char(
        string='District Name',
        required=True,
        tracking=True,
        help='Name of district - can be from list or manually entered'
    )
    
    phone = fields.Char(
        string='Phone Number',
        required=True,
        tracking=True
    )
    
    email = fields.Char(
        string='Email Address',
        required=True,
        tracking=True
    )
    
    # ========== ATTACHMENTS ==========
    
    photo = fields.Binary(
        string='Passport Photo',
        required=True,
        attachment=True
    )
    
    photo_filename = fields.Char(
        string='Photo Filename'
    )
    
    lc_letter = fields.Binary(
        string='LC Reference Letter',
        required=True,
        attachment=True
    )
    
    lc_letter_filename = fields.Char(
        string='LC Letter Filename'
    )
    
    # ========== WORKFLOW FIELDS ==========
    
    state = fields.Selection([
        ('new', 'New Application'),
        ('stage1_review', 'Stage 1 Review'),
        ('stage1_approved', 'Stage 1 Approved'),
        ('stage2_review', 'Stage 2 Review'),
        ('approved', 'Fully Approved'),
        ('rejected', 'Rejected'),
    ], string='Status', default='new', required=True, tracking=True)
    
    stage1_approver_id = fields.Many2one(
        'res.users',
        string='Stage 1 Approved By',
        readonly=True
    )
    
    stage1_approval_date = fields.Datetime(
        string='Stage 1 Approval Date',
        readonly=True
    )
    
    stage2_approver_id = fields.Many2one(
        'res.users',
        string='Stage 2 Approved By',
        readonly=True
    )
    
    stage2_approval_date = fields.Datetime(
        string='Stage 2 Approval Date',
        readonly=True
    )

    stage1_identity_verified = fields.Boolean(
        string='Identity details verified',
        tracking=True
    )

    stage1_documents_verified = fields.Boolean(
        string='Documents verified (Photo + LC Letter)',
        tracking=True
    )

    stage1_review_notes = fields.Text(
        string='Stage 1 Review Notes'
    )

    stage1_incomplete_override_reason = fields.Text(
        string='Stage 1 Incomplete Approval Reason',
        readonly=True,
        tracking=True
    )

    stage2_data_crosschecked = fields.Boolean(
        string='Records cross-check completed',
        tracking=True
    )

    stage2_review_notes = fields.Text(
        string='Stage 2 Review Notes'
    )

    stage2_incomplete_override_reason = fields.Text(
        string='Stage 2 Incomplete Approval Reason',
        readonly=True,
        tracking=True
    )

    rejection_category = fields.Selection(
        selection=REJECTION_CATEGORIES,
        string='Rejection Category',
        tracking=True
    )
    
    rejection_reason = fields.Text(
        string='Rejection Reason',
        tracking=True
    )

    rejected_by_id = fields.Many2one(
        'res.users',
        string='Rejected By',
        readonly=True
    )

    rejected_on = fields.Datetime(
        string='Rejected On',
        readonly=True
    )
    
    # ========== COMPUTED FIELDS & VALIDATIONS ==========
    
    @api.depends('date_of_birth')
    def _compute_age(self):
        """Calculate age from date of birth"""
        today = date.today()
        for record in self:
            if record.date_of_birth:
                record.age = relativedelta(today, record.date_of_birth).years
            else:
                record.age = 0
    
    @api.constrains('date_of_birth')
    def _check_age(self):
        """Ensure date of birth is not in the future"""
        for record in self:
            if record.date_of_birth:
                today = date.today()
                if record.date_of_birth > today:
                    raise ValidationError(
                        'Date of birth cannot be in the future! Please enter a valid date.'
                    )
                # Check if person is older than 120 years (likely a data entry error)
                age = relativedelta(today, record.date_of_birth).years
                if age > 120:
                    raise ValidationError(
                        'Please verify the date of birth. Age appears to be over 120 years.'
                    )
    
    @api.constrains('email')
    def _check_email(self):
        """Validate email format"""
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        for record in self:
            if record.email and not re.match(email_pattern, record.email):
                raise ValidationError('Please enter a valid email address.')
    
    @api.constrains('phone')
    def _check_phone(self):
        """Validate phone number format"""
        import re
        for record in self:
            if record.phone:
                # Remove spaces and special characters
                phone_clean = re.sub(r'[^\d+]', '', record.phone)
                if len(phone_clean) < 10:
                    raise ValidationError('Phone number must be at least 10 digits.')
    
    # ========== AUTO-NUMBERING ==========
    
    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if not vals.get('name') or vals.get('name') == 'New':
                vals['name'] = self.env['ir.sequence'].next_by_code(
                    'national.id.application'
                ) or 'New'
        return super().create(vals_list)

    def _get_missing_required_field_labels(self):
        """Return labels of required application fields that are currently missing."""
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

        return [
            label for field_name, label in required_checks if not self[field_name]
        ]

    def _ensure_required_data_for_review(self):
        """Block workflow transitions if core application data is incomplete."""
        missing_fields = self._get_missing_required_field_labels()
        if missing_fields:
            raise UserError(
                'Please complete all required application fields before continuing. '
                f'Missing: {", ".join(missing_fields)}'
            )
    
    # ========== WORKFLOW METHODS ==========
    
    def action_submit_stage1(self):
        """Move application to Stage 1 Review"""
        self.ensure_one()
        self.write({'state': 'stage1_review'})
        self.message_post(
            body='Application submitted for Stage 1 review.',
            subject='Stage 1 Review Started'
        )

    def action_open_stage1_approval_wizard(self):
        """Open guided Stage 1 approval wizard"""
        self.ensure_one()
        if self.state != 'stage1_review':
            raise UserError('Application must be in Stage 1 Review before approval.')
        return {
            'name': 'Stage 1 Verification',
            'type': 'ir.actions.act_window',
            'res_model': 'national.id.approval.wizard',
            'view_mode': 'form',
            'view_id': self.env.ref(
                'national_id_application.view_national_id_approval_wizard_form'
            ).id,
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
        """Approve application at Stage 1"""
        self.ensure_one()
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
                'Please provide a valid reason for approving an incomplete application.'
            )
        if not self.stage1_identity_verified or not self.stage1_documents_verified:
            raise UserError(
                'Complete Stage 1 verification checklist before approving.'
            )
        self.write({
            'state': 'stage1_approved',
            'stage1_approver_id': self.env.user.id,
            'stage1_approval_date': fields.Datetime.now(),
            'stage1_incomplete_override_reason': override_reason if missing_fields else False,
        })
        if missing_fields:
            self.message_post(
                body=(
                    f'Stage 1 approved by {self.env.user.name} with missing fields '
                    f'({", ".join(missing_fields)}). '
                    f'Override reason: {override_reason}'
                ),
                subject='Stage 1 Approved (Override)'
            )
        else:
            self.message_post(
                body=f'Stage 1 approved by {self.env.user.name}.',
                subject='Stage 1 Approved'
            )
    
    def action_submit_stage2(self):
        """Move application to Stage 2 Review"""
        self.ensure_one()
        if self.state != 'stage1_approved':
            raise UserError('Application must be Stage 1 approved first.')
        self.write({'state': 'stage2_review'})
        self.message_post(
            body='Application submitted for Stage 2 review.',
            subject='Stage 2 Review Started'
        )

    def action_open_stage2_approval_wizard(self):
        """Open guided Stage 2 approval wizard"""
        self.ensure_one()
        if self.state != 'stage2_review':
            raise UserError('Application must be in Stage 2 Review before final approval.')
        return {
            'name': 'Stage 2 Verification',
            'type': 'ir.actions.act_window',
            'res_model': 'national.id.approval.wizard',
            'view_mode': 'form',
            'view_id': self.env.ref(
                'national_id_application.view_national_id_approval_wizard_form'
            ).id,
            'target': 'new',
            'context': {
                'default_application_id': self.id,
                'default_stage': 'stage2',
                'default_stage2_data_crosschecked': self.stage2_data_crosschecked,
                'default_stage2_review_notes': self.stage2_review_notes,
            },
        }
    
    def action_approve_stage2(self):
        """Approve application at Stage 2 - Final approval"""
        self.ensure_one()
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
                'Please provide a valid reason for approving an incomplete application.'
            )
        if not self.stage2_data_crosschecked:
            raise UserError(
                'Complete Stage 2 cross-check before final approval.'
            )
        self.write({
            'state': 'approved',
            'stage2_approver_id': self.env.user.id,
            'stage2_approval_date': fields.Datetime.now(),
            'stage2_incomplete_override_reason': override_reason if missing_fields else False,
        })
        if missing_fields:
            self.message_post(
                body=(
                    f'Stage 2 approved by {self.env.user.name} with missing fields '
                    f'({", ".join(missing_fields)}). '
                    f'Override reason: {override_reason}. '
                    'Application fully approved.'
                ),
                subject='Application Fully Approved (Override)'
            )
        else:
            self.message_post(
                body=f'Stage 2 approved by {self.env.user.name}. Application fully approved.',
                subject='Application Fully Approved'
            )
    
    def action_open_rejection_wizard(self):
        """Open popup wizard to capture rejection category and reason"""
        self.ensure_one()
        return {
            'name': 'Reject Application',
            'type': 'ir.actions.act_window',
            'res_model': 'national.id.rejection.wizard',
            'view_mode': 'form',
            'view_id': self.env.ref(
                'national_id_application.view_national_id_rejection_wizard_form'
            ).id,
            'target': 'new',
            'context': {
                'default_application_id': self.id,
            },
        }

    def action_reject_with_reason(self, category, reason):
        """Reject application with category and reason from wizard"""
        self.ensure_one()
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
        self.message_post(
            body=(
                f'Application rejected by {self.env.user.name}. '
                f'Category: {category_label}. Reason: {clean_reason}'
            ),
            subject='Application Rejected'
        )
    
    def action_reset_to_new(self):
        """Reset application back to new state"""
        self.ensure_one()
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
        self.message_post(
            body=f'Application reset to New by {self.env.user.name}',
            subject='Application Reset'
        )
