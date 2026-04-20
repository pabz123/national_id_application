# -*- coding: utf-8 -*-
import base64
import json
from psycopg2 import IntegrityError
from odoo import http
from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.http import request, Response


class NationalIdMobileApiController(http.Controller):
    STATE_LABELS = {
        'new': 'Pending',
        'stage1_review': 'Verified',
        'stage1_approved': 'Senior Approval',
        'stage2_review': 'Senior Approval',
        'approved': 'Final Approval',
        'rejected': 'Rejected',
    }

    CORS_HEADERS = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': (
            'Origin, Content-Type, Accept, Authorization, X-Odoo-Database'
        ),
        'Access-Control-Max-Age': '86400',
    }

    def _json_response(self, payload, status=200):
        response = Response(
            json.dumps(payload),
            status=status,
            content_type='application/json;charset=utf-8',
        )
        for key, value in self.CORS_HEADERS.items():
            response.headers[key] = value
        return response

    def _read_json_payload(self):
        return request.httprequest.get_json(silent=True) or {}

    def _read_bearer_token(self):
        auth_header = request.httprequest.headers.get('Authorization') or ''
        prefix = 'bearer '
        if auth_header.lower().startswith(prefix):
            return auth_header[len(prefix):].strip()
        return ''

    def _get_authenticated_mobile_user(self):
        token = self._read_bearer_token()
        user = request.env['national.id.mobile.user'].sudo().user_from_token(token)
        if not user:
            raise AccessError('Invalid or expired authorization token.')
        return user

    def _build_duplicate_error_payload(self, message):
        lower_message = (message or '').lower()
        if (
            'national_id_application_email_unique' in lower_message
            or 'email address is already registered' in lower_message
        ):
            return {'success': False, 'message': 'An application with this email already exists.'}
        if (
            'national_id_application_phone_unique' in lower_message
            or 'phone number is already registered' in lower_message
        ):
            return {'success': False, 'message': 'An application with this phone number already exists.'}
        if (
            'national_id_mobile_user_email_unique' in lower_message
            or 'account with this email already exists' in lower_message
        ):
            return {'success': False, 'message': 'An account with this email already exists.'}
        if (
            'national_id_mobile_user_phone_unique' in lower_message
            or 'account with this phone number already exists' in lower_message
        ):
            return {'success': False, 'message': 'An account with this phone number already exists.'}
        return {'success': False, 'message': message or 'Request failed.'}

    def _build_stage_timeline(self, status_code):
        ordered = [
            ('new', 'Pending'),
            ('stage1_review', 'Verified'),
            ('stage2_review', 'Senior Approval'),
            ('approved', 'Final Approval'),
            ('rejected', 'Rejected'),
        ]
        if status_code == 'rejected':
            return [
                {'code': code, 'label': label, 'completed': code == 'rejected'}
                for code, label in ordered
            ]
        reached_states = {'new'}
        if status_code in {'stage1_review', 'stage1_approved', 'stage2_review', 'approved'}:
            reached_states.add('stage1_review')
        if status_code in {'stage1_approved', 'stage2_review', 'approved'}:
            reached_states.add('stage2_review')
        if status_code == 'approved':
            reached_states.add('approved')
        return [
            {'code': code, 'label': label, 'completed': code in reached_states}
            for code, label in ordered
        ]

    @http.route('/api/mobile/<path:subpath>', type='http', auth='public', methods=['OPTIONS'], csrf=False, cors='*')
    def mobile_options(self, subpath=None, **kwargs):
        return self._json_response({'success': True}, status=200)

    @http.route('/api/mobile/signup', type='http', auth='public', methods=['POST'], csrf=False, cors='*')
    def mobile_signup(self, **kwargs):
        payload = self._read_json_payload()
        data = payload or kwargs
        try:
            user = request.env['national.id.mobile.user'].sudo().signup_user(
                data.get('name'),
                data.get('email'),
                data.get('phone'),
                data.get('password'),
            )
            return self._json_response({
                'success': True,
                'message': 'Signup successful.',
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email,
                    'phone': user.phone,
                },
            }, status=201)
        except (UserError, ValidationError, IntegrityError) as exc:
            if isinstance(exc, IntegrityError):
                request.env.cr.rollback()
            return self._json_response(
                self._build_duplicate_error_payload(str(exc)),
                status=400,
            )

    @http.route('/api/mobile/login', type='http', auth='public', methods=['POST'], csrf=False, cors='*')
    def mobile_login(self, **kwargs):
        payload = self._read_json_payload()
        data = payload or kwargs
        try:
            user = request.env['national.id.mobile.user'].sudo().authenticate_user(
                data.get('email'),
                data.get('password'),
            )
            token = user.issue_session_token()
            return self._json_response({
                'success': True,
                'message': 'Login successful.',
                'token': token,
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email,
                    'phone': user.phone,
                },
            })
        except UserError as exc:
            return self._json_response({'success': False, 'message': str(exc)}, status=401)

    @http.route(
        '/api/mobile/application/submit',
        type='http',
        auth='public',
        methods=['POST'],
        csrf=False,
        cors='*',
    )
    def mobile_submit_application(self, **post):
        try:
            mobile_user = self._get_authenticated_mobile_user()
        except AccessError as exc:
            return self._json_response({'success': False, 'message': str(exc)}, status=401)

        photo_file = post.get('photo')
        lc_letter_file = post.get('lc_letter')
        photo_data = base64.b64encode(photo_file.read()) if photo_file else False
        lc_data = base64.b64encode(lc_letter_file.read()) if lc_letter_file else False

        try:
            application = request.env['national.id.application'].sudo().create({
                'mobile_user_id': mobile_user.id,
                'full_name': post.get('full_name'),
                'date_of_birth': post.get('date_of_birth'),
                'gender': post.get('gender'),
                'nationality_id': int(post.get('nationality_id')),
                'existing_nin': post.get('existing_nin'),
                'district_name': post.get('district_name'),
                'district_id': int(post.get('district_id')) if post.get('district_id') else False,
                'phone': (post.get('phone') or '').strip(),
                'email': (post.get('email') or '').strip(),
                'photo': photo_data,
                'photo_filename': photo_file.filename if photo_file else False,
                'lc_letter': lc_data,
                'lc_letter_filename': lc_letter_file.filename if lc_letter_file else False,
            })
            return self._json_response({
                'success': True,
                'message': 'Application submitted successfully.',
                'reference': application.name,
                'status': self.STATE_LABELS.get(application.state, application.state),
            }, status=201)
        except (TypeError, ValueError):
            return self._json_response(
                {'success': False, 'message': 'Please provide valid numeric IDs for country and district.'},
                status=400,
            )
        except (UserError, ValidationError, IntegrityError) as exc:
            if isinstance(exc, IntegrityError):
                request.env.cr.rollback()
            return self._json_response(
                self._build_duplicate_error_payload(str(exc)),
                status=400,
            )

    @http.route('/api/mobile/metadata', type='http', auth='public', methods=['GET'], csrf=False, cors='*')
    def mobile_form_metadata(self, **kwargs):
        countries = request.env['res.country'].sudo().search([], order='name')
        districts = request.env['national.id.district'].sudo().search([], order='name')
        return self._json_response({
            'success': True,
            'countries': [
                {'id': country.id, 'name': country.name}
                for country in countries
            ],
            'districts': [
                {
                    'id': district.id,
                    'name': district.name,
                    'country_id': district.country_id.id if district.country_id else None,
                }
                for district in districts
            ],
        })

    @http.route('/api/mobile/application/track', type='http', auth='public', methods=['GET'], csrf=False, cors='*')
    def mobile_track_application_query(self, **kwargs):
        reference = kwargs.get('reference')
        return self.mobile_track_application(reference)

    @http.route(
        '/api/mobile/application/track/<path:reference>',
        type='http',
        auth='public',
        methods=['GET'],
        csrf=False,
        cors='*',
    )
    def mobile_track_application(self, reference, **kwargs):
        clean_reference = (reference or '').strip()
        if not clean_reference:
            return self._json_response(
                {'success': False, 'message': 'Tracking number is required.'},
                status=400,
            )

        application = request.env['national.id.application'].sudo().search(
            [('name', '=', clean_reference)],
            limit=1,
        )
        if not application:
            return self._json_response(
                {'success': False, 'message': 'Application not found.'},
                status=404,
            )

        return self._json_response({
            'success': True,
            'application': {
                'reference': application.name,
                'full_name': application.full_name,
                'status_code': application.state,
                'status': self.STATE_LABELS.get(application.state, application.state),
                'timeline': self._build_stage_timeline(application.state),
                'rejection_reason': application.rejection_reason or '',
            },
        })
