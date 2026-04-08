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
    
    # SQL Constraints
    _sql_constraints = [
        ('email_unique', 'UNIQUE(email)', 'This email address is already registered!'),
        ('phone_unique', 'UNIQUE(phone)', 'This phone number is already registered!'),
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
    
    rejection_reason = fields.Text(
        string='Rejection Reason'
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
    
    # ========== WORKFLOW METHODS ==========
    
    def action_submit_stage1(self):
        """Move application to Stage 1 Review"""
        self.ensure_one()
        self.write({'state': 'stage1_review'})
        self.message_post(
            body='Application submitted for Stage 1 review.',
            subject='Stage 1 Review Started'
        )
    
    def action_approve_stage1(self):
        """Approve application at Stage 1"""
        self.ensure_one()
        self.write({
            'state': 'stage1_approved',
            'stage1_approver_id': self.env.user.id,
            'stage1_approval_date': fields.Datetime.now(),
        })
        self.message_post(
            body=f'Stage 1 approved by {self.env.user.name}',
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
    
    def action_approve_stage2(self):
        """Approve application at Stage 2 - Final approval"""
        self.ensure_one()
        self.write({
            'state': 'approved',
            'stage2_approver_id': self.env.user.id,
            'stage2_approval_date': fields.Datetime.now(),
        })
        self.message_post(
            body=f'Stage 2 approved by {self.env.user.name}. Application fully approved.',
            subject='Application Fully Approved'
        )
    
    def action_reject(self):
        """Reject the application"""
        self.ensure_one()
        if not self.rejection_reason:
            raise UserError('Please provide a rejection reason.')
        self.write({'state': 'rejected'})
        self.message_post(
            body=f'Application rejected by {self.env.user.name}. Reason: {self.rejection_reason}',
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
            'rejection_reason': False,
        })
        self.message_post(
            body=f'Application reset to New by {self.env.user.name}',
            subject='Application Reset'
        )
