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
    
    _sql_constraints = [
        ('name_country_unique', 'UNIQUE(name, country_id)', 
         'This district already exists for this country!'),
    ]
