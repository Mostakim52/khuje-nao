from flask import Blueprint, request, jsonify
from app import get_supabase
from app.utils import hash_password, check_password

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/firebase-google-login', methods=['POST'])
def firebase_google_login():
    """Handle Google OAuth login via Supabase."""
    data = request.get_json()
    access_token = data.get('access_token')
    
    if not access_token:
        return jsonify({'error': 'Access token required'}), 400
    
    try:
        sb = get_supabase()
        
        # Sign in with Google OAuth token
        result = sb.auth.sign_in_with_oauth_token(access_token)
        
        user = result.user
        
        # Check if user exists in our users table
        existing = sb.table('users').select('*').eq('email', user.email).execute()
        
        if not existing.data:
            # Create new user
            sb.table('users').insert({
                'name': user.user_metadata.get('full_name', user.email.split('@')[0]),
                'email': user.email,
                'supabase_auth_id': user.id,
                'profile_complete': False
            }).execute()
        
        return jsonify({
            'message': 'Login successful',
            'user': {
                'email': user.email,
                'name': user.user_metadata.get('full_name', ''),
            },
            'session': {
                'access_token': result.session.access_token,
                'refresh_token': result.session.refresh_token,
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 401

@auth_bp.route('/signup', methods=['POST'])
def signup():
    """Register a new user with email and password."""
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    name = data.get('name', '')
    
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400
    
    try:
        sb = get_supabase()
        
        # Create user in Supabase Auth
        result = sb.auth.sign_up({
            'email': email,
            'password': password,
            'options': {
                'data': {
                    'full_name': name
                }
            }
        })
        
        # Create user in our users table
        sb.table('users').insert({
            'name': name,
            'email': email,
            'password_hash': hash_password(password),
            'supabase_auth_id': result.user.id,
            'profile_complete': False
        }).execute()
        
        return jsonify({
            'message': 'Signup successful',
            'user': {
                'email': email,
                'name': name,
            }
        }), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@auth_bp.route('/login', methods=['POST'])
def login():
    """Login with email and password."""
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400
    
    try:
        sb = get_supabase()
        
        result = sb.auth.sign_in_with_password({
            'email': email,
            'password': password
        })
        
        return jsonify({
            'message': 'Login successful',
            'user': {
                'email': result.user.email,
                'name': result.user.user_metadata.get('full_name', ''),
            },
            'session': {
                'access_token': result.session.access_token,
                'refresh_token': result.session.refresh_token,
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 401

@auth_bp.route('/check-user-exists', methods=['POST'])
def check_user_exists():
    """Check if a user exists by email."""
    data = request.get_json()
    email = data.get('email')
    
    if not email:
        return jsonify({'error': 'Email required'}), 400
    
    try:
        sb = get_supabase()
        result = sb.table('users').select('id').eq('email', email).execute()
        
        return jsonify({
            'exists': len(result.data) > 0
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/user-by-email/<email>', methods=['GET'])
def get_user_by_email(email):
    """Get user details by email."""
    try:
        sb = get_supabase()
        result = sb.table('users').select('*').eq('email', email).execute()
        
        if result.data:
            return jsonify(result.data[0]), 200
        else:
            return jsonify({'error': 'User not found'}), 404
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/profile', methods=['GET', 'POST'])
def profile():
    """Get or save user profile."""
    # For now, simple implementation
    # In production, verify Supabase JWT token
    return jsonify({'error': 'Not implemented'}), 501
