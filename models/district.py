# -*- coding: utf-8 -*-
from odoo import models, fields


class NationalIdDistrict(models.Model):
    _name = 'national.id.district'
    _description = 'District'
    _order = 'name'
    
    name = fields.Char(
        string='District Name',
        required=True
    )
    
    country_id = fields.Many2one(
        'res.country',
        string='Country',
        required=True
    )
    
    _name_country_unique = models.Constraint(
        'UNIQUE(name, country_id)',
        'This district already exists for this country!'
    )
