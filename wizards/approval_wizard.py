# -*- coding: utf-8 -*-
from odoo import models, fields, api
from odoo.exceptions import UserError


class NationalIdApprovalWizard(models.TransientModel):
    _name = 'national.id.approval.wizard'
    _description = 'National ID Approval Wizard'

    stage = fields.Selection(
        [
            ('stage1', 'Stage 1'),
            ('stage2', 'Stage 2'),
        ],
        required=True,
        readonly=True
    )
    application_id = fields.Many2one(
        'national.id.application',
        string='Application',
        required=True,
        readonly=True
    )

    stage1_identity_verified = fields.Boolean(
        string='Identity details verified'
    )
    stage1_documents_verified = fields.Boolean(
        string='Documents verified (Photo + LC Letter)'
    )
    stage1_review_notes = fields.Text(
        string='Stage 1 Review Notes'
    )

    stage2_data_crosschecked = fields.Boolean(
        string='Records cross-check completed'
    )
    stage2_review_notes = fields.Text(
        string='Stage 2 Review Notes'
    )

    has_missing_required_fields = fields.Boolean(
        string='Has Missing Required Fields',
        readonly=True
    )
    missing_required_fields = fields.Text(
        string='Missing Required Fields',
        readonly=True
    )
    allow_incomplete_approval = fields.Boolean(
        string='Allow approval with missing fields'
    )
    incomplete_approval_reason = fields.Text(
        string='Reason for approving incomplete application'
    )

    @api.model
    def default_get(self, fields_list):
        values = super().default_get(fields_list)
        application_id = values.get('application_id') or self.env.context.get('default_application_id')
        if application_id:
            app = self.env['national.id.application'].browse(application_id)
            missing = app._get_missing_required_field_labels()
            if missing:
                values['has_missing_required_fields'] = True
                values['missing_required_fields'] = '\n'.join(f'- {label}' for label in missing)
        return values

    def action_confirm_approval(self):
        self.ensure_one()
        app = self.application_id
        missing = app._get_missing_required_field_labels()
        override_reason = (self.incomplete_approval_reason or '').strip()

        if missing:
            if not self.allow_incomplete_approval:
                raise UserError(
                    'This application has missing required fields. '
                    'Tick "Allow approval with missing fields" to proceed.'
                )
            if not override_reason:
                raise UserError(
                    'Please provide a valid reason for approving an incomplete application.'
                )

        app_for_approval = app.with_context(
            allow_incomplete_approval=bool(missing and self.allow_incomplete_approval),
            incomplete_approval_reason=override_reason,
        )

        if self.stage == 'stage1':
            if not self.stage1_identity_verified or not self.stage1_documents_verified:
                raise UserError('Please complete the Stage 1 checklist to approve.')
            app.write({
                'stage1_identity_verified': self.stage1_identity_verified,
                'stage1_documents_verified': self.stage1_documents_verified,
                'stage1_review_notes': self.stage1_review_notes,
            })
            app_for_approval.action_approve_stage1()
        else:
            if not self.stage2_data_crosschecked:
                raise UserError('Please complete the Stage 2 cross-check to approve.')
            app.write({
                'stage2_data_crosschecked': self.stage2_data_crosschecked,
                'stage2_review_notes': self.stage2_review_notes,
            })
            app_for_approval.action_approve_stage2()

        return {'type': 'ir.actions.act_window_close'}
