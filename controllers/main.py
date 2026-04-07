# -*- coding: utf-8 -*-
import base64
from odoo import http
from odoo.http import request


class NationalIdController(http.Controller):
    
    @http.route('/national-id/apply', type='http', auth='public', website=True)
    def application_form(self, **kwargs):
        """
        Display the public application form.
        
        WHY: This route shows the HTML form where citizens fill in their details.
        auth='public' means anyone can access it without logging in.
        website=True applies Odoo's website styling.
        """
        countries = request.env['res.country'].sudo().search([])
        districts = request.env['national.id.district'].sudo().search([])
        return request.render(
            'national_id_application.application_form_template',
            {
                'countries': countries,
                'districts': districts,
            }
        )
    
    @http.route('/national-id/submit', type='http', auth='public', 
                website=True, methods=['POST'], csrf=False)
    def submit_application(self, **post):
        """
        Process the submitted application form.
        
        WHY: When citizen clicks Submit, browser POSTs data here.
        We create the application record and upload the files.
        csrf=False allows public form submission.
        """
        # Read uploaded files
        photo_file = post.get('photo')
        lc_letter_file = post.get('lc_letter')
        
        # Convert files to base64 (Odoo stores binary fields this way)
        photo_data = base64.b64encode(photo_file.read()) if photo_file else False
        lc_data = base64.b64encode(lc_letter_file.read()) if lc_letter_file else False
        
        # Create the application record
        application = request.env['national.id.application'].sudo().create({
            'full_name': post.get('full_name'),
            'date_of_birth': post.get('date_of_birth'),
            'gender': post.get('gender'),
            'nationality_id': int(post.get('nationality_id')),
            'existing_id_number': post.get('existing_id_number'),
            'district': post.get('district'),
            'phone': post.get('phone'),
            'email': post.get('email'),
            'photo': photo_data,
            'photo_filename': photo_file.filename if photo_file else False,
            'lc_letter': lc_data,
            'lc_letter_filename': lc_letter_file.filename if lc_letter_file else False,
        })
        
        # Show success page with the application reference number
        return request.render(
            'national_id_application.application_success_template',
            {'reference': application.name}
        )
