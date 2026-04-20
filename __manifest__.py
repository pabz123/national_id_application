# -*- coding: utf-8 -*-
{
    'name': 'National ID Application',
    'version': '19.0.1.1.0',
    'category': 'Government',
    'summary': 'Online National ID Application Portal',
    'author': 'Precious Mulungi Pabire',
    'depends': ['base', 'mail', 'web', 'portal', 'website'],
    'data': [
        'security/national_id_security.xml',
        'security/ir.model.access.csv',
        'data/districts_data.xml',
        'views/district_views.xml',
        'views/approval_wizard_views.xml',
        'views/rejection_wizard_views.xml',
        'views/national_id_views.xml',
        'views/national_id_menus.xml',
        'views/website_menu.xml',
        'templates/application_form.xml',
    ],
    'installable': True,
    'application': True,
    'license': 'LGPL-3',
}
