from flask import Blueprint, request, jsonify
from app import socketio
from app.models import UserModel, LostItemModel, FoundItemModel, MessageModel
from app.storage import upload_image_to_storage
from flask_socketio import emit, join_room
import json
from datetime import datetime

main_bp = Blueprint('main', __name__)

# ========== Health Check ==========
@main_bp.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'}), 200

# ========== User Endpoints ==========
@main_bp.route('/users', methods=['POST'])
def create_user():
    data = request.get_json()
    user = UserModel.create(data)
    if user:
        return jsonify(user), 201
    return jsonify({'error': 'Failed to create user'}), 400

# ========== Lost Item Endpoints ==========
@main_bp.route('/lost-items', methods=['POST'])
def report_lost_item():
    data = request.get_json()
    
    # Handle image upload if present
    if 'image' in request.files:
        image = request.files['image']
        image_url = upload_image_to_storage(
            image.read(),
            image.filename,
            'lost-items'
        )
        data['image_path'] = image_url
    
    data['is_found'] = False
    data['is_approved'] = False
    data['created_at'] = datetime.utcnow().isoformat()
    
    item = LostItemModel.create(data)
    if item:
        return jsonify(item), 201
    return jsonify({'error': 'Failed to report lost item'}), 400

@main_bp.route('/lost-items', methods=['GET'])
def get_lost_items():
    items = LostItemModel.get_approved()
    return jsonify(items), 200

@main_bp.route('/lost-items-admin', methods=['GET'])
def get_lost_items_admin():
    items = LostItemModel.get_pending()
    return jsonify(items), 200

@main_bp.route('/lost-items/<item_id>/approve', methods=['POST'])
def approve_lost_item(item_id):
    item = LostItemModel.update(item_id, {'is_approved': True})
    if item:
        return jsonify(item), 200
    return jsonify({'error': 'Item not found'}), 404

@main_bp.route('/lost-items/<item_id>/found', methods=['POST'])
def mark_item_found(item_id):
    item = LostItemModel.get_by_id(item_id)
    if not item:
        return jsonify({'error': 'Item not found'}), 404
    
    # Create found item
    found_data = {
        'description': item['description'],
        'location': item['location'],
        'image_path': item.get('image_path'),
        'reported_by': item['reported_by'],
        'found_at': datetime.utcnow().isoformat()
    }
    FoundItemModel.create(found_data)
    
    # Mark lost item as found
    LostItemModel.update(item_id, {'is_found': True})
    
    return jsonify({'message': 'Item marked as found'}), 200

# ========== Found Item Endpoints ==========
@main_bp.route('/found-items', methods=['POST'])
def report_found_item():
    data = request.get_json()
    
    if 'image' in request.files:
        image = request.files['image']
        image_url = upload_image_to_storage(
            image.read(),
            image.filename,
            'found-items'
        )
        data['image_path'] = image_url
    
    data['created_at'] = datetime.utcnow().isoformat()
    
    item = FoundItemModel.create(data)
    if item:
        return jsonify(item), 201
    return jsonify({'error': 'Failed to report found item'}), 400

@main_bp.route('/found-items', methods=['GET'])
def get_found_items():
    items = FoundItemModel.get_all()
    return jsonify(items), 200

# ========== Search Endpoint ==========
@main_bp.route('/search-lost-items', methods=['GET'])
def search_lost_items():
    query = request.args.get('q', '')
    if not query:
        return jsonify([]), 200
    
    items = LostItemModel.search(query)
    return jsonify(items), 200

# ========== Activity Feed ==========
@main_bp.route('/activity-feed', methods=['GET'])
def activity_feed():
    items = LostItemModel.get_approved()
    return jsonify(items[:20]), 200

# ========== Chat Endpoints (HTTP) ==========
@main_bp.route('/send_message', methods=['POST'])
def send_message_http():
    data = request.get_json()
    
    message_data = {
        'author_id': data.get('author_id'),
        'receiver_id': data.get('receiver_id'),
        'text': data.get('text'),
        'is_read': False,
        'created_at': datetime.utcnow().isoformat()
    }
    
    message = MessageModel.create(message_data)
    if message:
        # Broadcast to SocketIO room
        room = get_chat_room(message_data['author_id'], message_data['receiver_id'])
        socketio.emit('new_message', message, room=room)
        return jsonify(message), 201
    return jsonify({'error': 'Failed to send message'}), 400

@main_bp.route('/get_messages', methods=['POST'])
def get_messages():
    data = request.get_json()
    user1 = data.get('author_id')
    user2 = data.get('receiver_id')
    
    messages = MessageModel.get_between_users(user1, user2)
    return jsonify(messages), 200

@main_bp.route('/get_chats', methods=['POST'])
def get_chats():
    data = request.get_json()
    user_id = data.get('user_id')
    
    chats = MessageModel.get_chats_for_user(user_id)
    return jsonify(chats), 200

@main_bp.route('/mark_read', methods=['POST'])
def mark_read():
    data = request.get_json()
    author_id = data.get('author_id')
    receiver_id = data.get('receiver_id')
    
    MessageModel.mark_as_read(author_id, receiver_id)
    return jsonify({'message': 'Messages marked as read'}), 200

# ========== Helper Functions ==========
def get_chat_room(user1, user2):
    """Get a consistent room name for two users."""
    users = sorted([user1, user2])
    return f"{users[0]}_{users[1]}"

# ========== SocketIO Events ==========
@socketio.on('connect')
def handle_connect():
    print(f'Client connected: {request.sid}')

@socketio.on('disconnect')
def handle_disconnect():
    print(f'Client disconnected: {request.sid}')

@socketio.on('join_chat')
def handle_join_chat(data):
    """Join a chat room for two users."""
    user1 = data.get('user1')
    user2 = data.get('user2')
    
    if user1 and user2:
        room = get_chat_room(user1, user2)
        join_room(room)
        emit('joined_chat', {'room': room})

@socketio.on('send_message')
def handle_send_message(data):
    """Handle real-time message sending."""
    message_data = {
        'author_id': data.get('author_id'),
        'receiver_id': data.get('receiver_id'),
        'text': data.get('text'),
        'is_read': False,
        'created_at': datetime.utcnow().isoformat()
    }
    
    message = MessageModel.create(message_data)
    if message:
        room = get_chat_room(message_data['author_id'], message_data['receiver_id'])
        emit('new_message', message, room=room)