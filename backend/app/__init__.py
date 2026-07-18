from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO
from supabase import create_client, Client
from config import Config

# Global Supabase client
supabase: Client = None

# Global SocketIO instance
socketio = SocketIO(cors_allowed_origins="*", async_mode='eventlet')

def create_app():
    global supabase
    
    app = Flask(__name__)
    app.config.from_object(Config)
    
    # Initialize Supabase client
    supabase = create_client(
        app.config['SUPABASE_URL'],
        app.config['SUPABASE_KEY']
    )
    
    # Initialize CORS
    CORS(app)
    
    # Initialize SocketIO
    socketio.init_app(app)
    
    # Register blueprints
    from app.views import main_bp
    from app.auth import auth_bp
    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    
    # Error handlers
    @app.errorhandler(400)
    def bad_request(e):
        return {'error': 'Bad request'}, 400
    
    @app.errorhandler(404)
    def not_found(e):
        return {'error': 'Not found'}, 404
    
    @app.errorhandler(405)
    def method_not_allowed(e):
        return {'error': 'Method not allowed'}, 405
    
    @app.errorhandler(500)
    def internal_error(e):
        return {'error': 'Internal server error'}, 500
    
    return app

def get_supabase():
    """Get the global Supabase client."""
    return supabase
