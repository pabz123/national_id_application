# -*- coding: utf-8 -*-
import re
import secrets
from datetime import timedelta
from werkzeug.security import check_password_hash, generate_password_hash
from odoo import models, fields, api
from odoo.exceptions import UserError, ValidationError


class NationalIdMobileUser(models.Model):
    _name = 'national.id.mobile.user'
    _description = 'National ID Mobile User'
    _order = 'create_date desc'

    _email_unique = models.Constraint(
        'UNIQUE(email)',
        'An account with this email already exists.'
    )
    _phone_unique = models.Constraint(
        'UNIQUE(phone)',
        'An account with this phone number already exists.'
    )

    name = fields.Char(required=True)
    email = fields.Char(required=True, index=True)
    phone = fields.Char(required=True, index=True)
    password_hash = fields.Char(required=True)
    session_token = fields.Char(index=True, copy=False)
    session_expiry = fields.Datetime(copy=False)
    active = fields.Boolean(default=True)
    application_ids = fields.One2many(
        'national.id.application', 'mobile_user_id', string='Applications')

    @api.constrains('email')
    def _check_email(self):
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        for record in self:
            if not record.email or not re.match(email_pattern, record.email):
                raise ValidationError('Please provide a valid email address.')

    @api.constrains('phone')
    def _check_phone(self):
        for record in self:
            phone_clean = re.sub(r'[^\d+]', '', record.phone or '')
            if len(phone_clean) < 10:
                raise ValidationError('Phone number must be at least 10 digits.')

    @api.model
    def signup_user(self, name, email, phone, password):
        clean_name = (name or '').strip()
        clean_email = (email or '').strip().lower()
        clean_phone = (phone or '').strip()
        clean_password = (password or '').strip()

        if not clean_name:
            raise UserError('Name is required.')
        if not clean_email:
            raise UserError('Email is required.')
        if not clean_phone:
            raise UserError('Phone number is required.')
        if len(clean_password) < 6:
            raise UserError('Password must be at least 6 characters.')

        return self.create({
            'name': clean_name,
            'email': clean_email,
            'phone': clean_phone,
            'password_hash': generate_password_hash(clean_password),
        })

    @api.model
    def authenticate_user(self, email, password):
        clean_email = (email or '').strip().lower()
        clean_password = (password or '').strip()

        if not clean_email or not clean_password:
            raise UserError('Email and password are required.')

        user = self.search(
            [('email', '=', clean_email), ('active', '=', True)],
            limit=1,
        )
        if not user or not user.check_password(clean_password):
            raise UserError('Invalid email or password.')
        return user

    def check_password(self, password):
        self.ensure_one()
        return bool(password) and check_password_hash(
            self.password_hash or '',
            password,
        )

    def issue_session_token(self):
        self.ensure_one()
        token = secrets.token_urlsafe(32)
        self.write({
            'session_token': token,
            'session_expiry': fields.Datetime.now() + timedelta(days=7),
        })
        return token

    @api.model
    def user_from_token(self, token):
        clean_token = (token or '').strip()
        if not clean_token:
            return self.browse()
        now = fields.Datetime.now()
        return self.search([
            ('session_token', '=', clean_token),
            ('session_expiry', '>', now),
            ('active', '=', True),
        ], limit=1)
