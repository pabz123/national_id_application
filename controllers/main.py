# -*- coding: utf-8 -*-
import base64
from psycopg2 import IntegrityError
from odoo import http
from odoo.exceptions import UserError, ValidationError
from odoo.http import request


class NationalIdController(http.Controller):

    def _prepare_form_render_values(self, post=None, error_message=None, field_errors=None):
        countries = request.env['res.country'].sudo().search([])
        districts = request.env['national.id.district'].sudo().search([])
        form_data = {
            key: value for key, value in (post or {}).items()
            if key not in ('photo', 'lc_letter')
        }
        return {
            'countries': countries,
            'districts': districts,
            'form_data': form_data,
            'error_message': error_message,
            'field_errors': field_errors or {},
        }

    @http.route('/national-id/apply', type='http', auth='public', website=True)
    def application_form(self, **kwargs):
        """
        Display the public application form.
        
        WHY: This route shows the HTML form where citizens fill in their details.
        auth='public' means anyone can access it without logging in.
        website=True applies Odoo's website styling.
        """
        return request.render(
            'national_id_application.application_form_template',
            self._prepare_form_render_values()
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

        clean_post = dict(post)
        clean_post['phone'] = (post.get('phone') or '').strip()
        clean_post['email'] = (post.get('email') or '').strip()

        try:
            application_vals = {
                'full_name': post.get('full_name'),
                'date_of_birth': post.get('date_of_birth'),
                'gender': post.get('gender'),
                'nationality_id': int(post.get('nationality_id')),
                'existing_nin': post.get('existing_nin'),
                'district_name': post.get('district_name'),
                'district_id': int(post.get('district_id')) if post.get('district_id') else False,
                'phone': clean_post['phone'],
                'email': clean_post['email'],
                'photo': photo_data,
                'photo_filename': photo_file.filename if photo_file else False,
                'lc_letter': lc_data,
                'lc_letter_filename': lc_letter_file.filename if lc_letter_file else False,
            }
        except (TypeError, ValueError):
            return request.render(
                'national_id_application.application_form_template',
                self._prepare_form_render_values(
                    post=clean_post,
                    error_message='Please fill in all required fields correctly and try again.',
                ),
            )

        try:
            # Create the application record
            application = request.env['national.id.application'].sudo().create(application_vals)
        except (ValidationError, UserError, IntegrityError) as exc:
            if isinstance(exc, IntegrityError):
                request.env.cr.rollback()
            message = str(exc)
            lower_message = message.lower()
            field_errors = {}
            error_message = message

            if (
                'email address is already registered' in lower_message
                or 'national_id_application_email_unique' in lower_message
            ):
                field_errors['email'] = 'This email is already registered. Please use a different one.'
                error_message = 'An application with this email already exists.'
            elif (
                'phone number is already registered' in lower_message
                or 'national_id_application_phone_unique' in lower_message
            ):
                field_errors['phone'] = 'This phone number is already registered. Please use a different one.'
                error_message = 'An application with this phone number already exists.'

            return request.render(
                'national_id_application.application_form_template',
                self._prepare_form_render_values(
                    post=clean_post,
                    error_message=error_message,
                    field_errors=field_errors,
                ),
            )

        # Show success page with the application reference number
        return request.render(
            'national_id_application.application_success_template',
            {'reference': application.name}
        )
