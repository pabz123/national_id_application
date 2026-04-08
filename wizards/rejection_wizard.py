# -*- coding: utf-8 -*-
from odoo import models, fields


class NationalIdRejectionWizard(models.TransientModel):
    _name = 'national.id.rejection.wizard'
    _description = 'National ID Rejection Wizard'

    application_id = fields.Many2one(
        'national.id.application',
        string='Application',
        required=True,
        readonly=True
    )

    rejection_category = fields.Selection(
        selection=[
            ('incomplete_information', 'Incomplete Information'),
            ('invalid_documents', 'Invalid Documents'),
            ('duplicate_application', 'Duplicate Application'),
            ('failed_verification', 'Failed Verification'),
            ('other', 'Other'),
        ],
        string='Rejection Category',
        required=True,
        default='incomplete_information'
    )

    rejection_reason = fields.Text(
        string='Rejection Reason',
        required=True
    )

    def action_confirm_rejection(self):
        self.ensure_one()
        self.application_id.action_reject_with_reason(
            self.rejection_category,
            self.rejection_reason
        )
        return {'type': 'ir.actions.act_window_close'}
