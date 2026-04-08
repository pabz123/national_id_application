# -*- coding: utf-8 -*-
from odoo import models, fields
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

    def action_confirm_approval(self):
        self.ensure_one()
        app = self.application_id

        if self.stage == 'stage1':
            if not self.stage1_identity_verified or not self.stage1_documents_verified:
                raise UserError('Please complete the Stage 1 checklist to approve.')
            app.write({
                'stage1_identity_verified': self.stage1_identity_verified,
                'stage1_documents_verified': self.stage1_documents_verified,
                'stage1_review_notes': self.stage1_review_notes,
            })
            app.action_approve_stage1()
        else:
            if not self.stage2_data_crosschecked:
                raise UserError('Please complete the Stage 2 cross-check to approve.')
            app.write({
                'stage2_data_crosschecked': self.stage2_data_crosschecked,
                'stage2_review_notes': self.stage2_review_notes,
            })
            app.action_approve_stage2()

        return {'type': 'ir.actions.act_window_close'}
