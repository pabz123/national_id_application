# -*- coding: utf-8 -*-
"""
controllers/mobile_api.py  –  COMPLETE REPLACEMENT
Key changes vs original:
  1. submit endpoint now reads next_of_kin_name / next_of_kin_phone
  2. submit enforces one-active-application-per-user (returns 409 if duplicate)
  3. signup / login unchanged (already correct)
  4. track response unchanged
"""
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

    # ── helpers ───────────────────────────────────────────────────────────────

    def _json_response(self, payload, status=200):
        return Response(
            json.dumps(payload),
            status=status,
            content_type='application/json;charset=utf-8',
        )

    def _read_json_payload(self):
        return request.httprequest.get_json(silent=True) or {}

    def _read_bearer_token(self):
        auth = request.httprequest.headers.get('Authorization') or ''
        prefix = 'bearer '
        if auth.lower().startswith(prefix):
            return auth[len(prefix):].strip()
        return ''

    def _get_authenticated_mobile_user(self):
        token = self._read_bearer_token()
        user = request.env['national.id.mobile.user'].sudo().user_from_token(token)
        if not user:
            raise AccessError('Invalid or expired authorization token.')
        return user

    def _build_duplicate_error_payload(self, message):
        lower = (message or '').lower()
        if 'active application with this email' in lower:
            return {'success': False, 'message': 'An active application with this email already exists.'}
        if 'active application with this phone' in lower:
            return {'success': False, 'message': 'An active application with this phone number already exists.'}
        if 'national_id_application_email_unique' in lower or 'email address is already registered' in lower:
            return {'success': False, 'message': 'An application with this email already exists.'}
        if 'national_id_application_phone_unique' in lower or 'phone number is already registered' in lower:
            return {'success': False, 'message': 'An application with this phone already exists.'}
        if 'national_id_mobile_user_email_unique' in lower or 'account with this email' in lower:
            return {'success': False, 'message': 'An account with this email already exists.'}
        if 'national_id_mobile_user_phone_unique' in lower or 'account with this phone' in lower:
            return {'success': False, 'message': 'An account with this phone already exists.'}
        return {'success': False, 'message': message or 'Request failed.'}

    def _build_decision_feedback(self, application):
        if application.state == 'approved':
            reason = (
                (application.stage2_review_notes or '').strip()
                or (application.stage1_review_notes or '').strip()
                or 'Your application passed all verification stages.'
            )
            return {
                'decision_reason': reason,
                'next_step_recommendation': (
                    'Keep your tracking number and await collection guidance from the issuing office.'
                ),
            }
        if application.state == 'rejected':
            guidance = {
                'incomplete_information': 'Update missing fields and reapply with complete information.',
                'invalid_documents': 'Prepare clear, valid documents and submit a fresh application.',
                'duplicate_application': 'Use your existing active tracking number, or reapply only after your previous application is closed.',
                'failed_verification': 'Review your details carefully, correct inconsistencies, and reapply.',
                'other': 'Follow the rejection reason, make corrections, and submit a new application.',
            }
            return {
                'decision_reason': (
                    (application.rejection_reason or '').strip()
                    or 'The application did not pass verification.'
                ),
                'next_step_recommendation': guidance.get(
                    application.rejection_category or 'other', guidance['other']
                ),
            }
        return {
            'decision_reason': '',
            'next_step_recommendation': (
                'Your application is under review. Keep checking this tracking page for updates.'
            ),
        }

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
                {'code': c, 'label': l, 'completed': c == 'rejected'}
                for c, l in ordered
            ]
        reached = {'new'}
        if status_code in {'stage1_review', 'stage1_approved', 'stage2_review', 'approved'}:
            reached.add('stage1_review')
        if status_code in {'stage1_approved', 'stage2_review', 'approved'}:
            reached.add('stage2_review')
        if status_code == 'approved':
            reached.add('approved')
        return [{'code': c, 'label': l, 'completed': c in reached} for c, l in ordered]

    # ── CORS pre-flight ───────────────────────────────────────────────────────

    @http.route('/api/mobile/<path:subpath>',
                type='http', auth='public', methods=['OPTIONS'],
                csrf=False, cors='*')
    def mobile_options(self, subpath=None, **kwargs):
        return self._json_response({'success': True})

    # ── Signup ────────────────────────────────────────────────────────────────

    @http.route('/api/mobile/signup',
                type='http', auth='public', methods=['POST'],
                csrf=False, cors='*')
    def mobile_signup(self, **kwargs):
        data = self._read_json_payload() or kwargs
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
                self._build_duplicate_error_payload(str(exc)), status=400)

    # ── Login ─────────────────────────────────────────────────────────────────

    @http.route('/api/mobile/login',
                type='http', auth='public', methods=['POST'],
                csrf=False, cors='*')
    def mobile_login(self, **kwargs):
        data = self._read_json_payload() or kwargs
        try:
            user = request.env['national.id.mobile.user'].sudo().authenticate_user(
                data.get('email'), data.get('password'))
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

    # ── Submit application ────────────────────────────────────────────────────

    @http.route('/api/mobile/application/submit',
                type='http', auth='public', methods=['POST'],
                csrf=False, cors='*')
    def mobile_submit_application(self, **post):
        # 1. Authenticate
        try:
            mobile_user = self._get_authenticated_mobile_user()
        except AccessError as exc:
            return self._json_response({'success': False, 'message': str(exc)}, status=401)

        # 2. One-application-per-user guard
        #    A user may only have ONE non-rejected application at a time.
        existing = request.env['national.id.application'].sudo().search([
            ('mobile_user_id', '=', mobile_user.id),
            ('state', '!=', 'rejected'),
        ], limit=1)
        if existing:
            return self._json_response({
                'success': False,
                'message': (
                    f'You already have an active application '
                    f'(reference: {existing.name}, status: '
                    f'{self.STATE_LABELS.get(existing.state, existing.state)}). '
                    f'You can only submit a new application after your '
                    f'current one has been rejected.'
                ),
                'existing_reference': existing.name,
                'existing_status': self.STATE_LABELS.get(existing.state, existing.state),
            }, status=409)

        # 3. Read uploaded files
        photo_file = post.get('photo')
        lc_file = post.get('lc_letter')
        photo_data = base64.b64encode(photo_file.read()) if photo_file else False
        lc_data = base64.b64encode(lc_file.read()) if lc_file else False

        # 4. Create application
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
                'next_of_kin_name': (post.get('next_of_kin_name') or '').strip(),
                'next_of_kin_phone': (post.get('next_of_kin_phone') or '').strip(),
                'photo': photo_data,
                'photo_filename': photo_file.filename if photo_file else False,
                'lc_letter': lc_data,
                'lc_letter_filename': lc_file.filename if lc_file else False,
            })
            return self._json_response({
                'success': True,
                'message': 'Application submitted successfully.',
                'reference': application.name,
                'status': self.STATE_LABELS.get(application.state, application.state),
            }, status=201)
        except (TypeError, ValueError):
            return self._json_response({
                'success': False,
                'message': 'Invalid country or district ID.',
            }, status=400)
        except (UserError, ValidationError, IntegrityError) as exc:
            if isinstance(exc, IntegrityError):
                request.env.cr.rollback()
            return self._json_response(
                self._build_duplicate_error_payload(str(exc)), status=400)

    # ── Metadata ──────────────────────────────────────────────────────────────

    @http.route('/api/mobile/metadata',
                type='http', auth='public', methods=['GET'],
                csrf=False, cors='*')
    def mobile_form_metadata(self, **kwargs):
        countries = request.env['res.country'].sudo().search([], order='name')
        districts = request.env['national.id.district'].sudo().search([], order='name')
        return self._json_response({
            'success': True,
            'countries': [{'id': c.id, 'name': c.name} for c in countries],
            'districts': [
                {
                    'id': d.id,
                    'name': d.name,
                    'country_id': d.country_id.id if d.country_id else None,
                }
                for d in districts
            ],
        })

    # ── Track ─────────────────────────────────────────────────────────────────

    @http.route('/api/mobile/application/track',
                type='http', auth='public', methods=['GET'],
                csrf=False, cors='*')
    def mobile_track_application_query(self, **kwargs):
        return self.mobile_track_application(kwargs.get('reference'))

    @http.route('/api/mobile/application/track/<path:reference>',
                type='http', auth='public', methods=['GET'],
                csrf=False, cors='*')
    def mobile_track_application(self, reference, **kwargs):
        ref = (reference or '').strip()
        if not ref:
            return self._json_response(
                {'success': False, 'message': 'Tracking number is required.'}, status=400)
        app = request.env['national.id.application'].sudo().search(
            [('name', '=', ref)], limit=1)
        if not app:
            return self._json_response(
                {'success': False, 'message': 'Application not found.'}, status=404)
        feedback = self._build_decision_feedback(app)
        return self._json_response({
            'success': True,
            'application': {
                'reference': app.name,
                'full_name': app.full_name,
                'status_code': app.state,
                'status': self.STATE_LABELS.get(app.state, app.state),
                'timeline': self._build_stage_timeline(app.state),
                'rejection_reason': app.rejection_reason or '',
                'decision_reason': feedback['decision_reason'],
                'next_step_recommendation': feedback['next_step_recommendation'],
            },
        })

    # ── User status (check if user has active application) ────────────────────

    @http.route('/api/mobile/application/status',
                type='http', auth='public', methods=['GET'],
                csrf=False, cors='*')
    def mobile_user_application_status(self, **kwargs):
        """Returns the logged-in user's current (non-rejected) application, if any."""
        try:
            mobile_user = self._get_authenticated_mobile_user()
        except AccessError as exc:
            return self._json_response({'success': False, 'message': str(exc)}, status=401)

        app = request.env['national.id.application'].sudo().search([
            ('mobile_user_id', '=', mobile_user.id),
            ('state', '!=', 'rejected'),
        ], limit=1)

        if not app:
            return self._json_response({
                'success': True,
                'has_active_application': False,
            })
        return self._json_response({
            'success': True,
            'has_active_application': True,
            'reference': app.name,
            'status': self.STATE_LABELS.get(app.state, app.state),
            'status_code': app.state,
        })
