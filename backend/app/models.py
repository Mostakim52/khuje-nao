from app import get_supabase
from datetime import datetime

class UserModel:
    @staticmethod
    def get_by_email(email):
        sb = get_supabase()
        result = sb.table('users').select('*').eq('email', email).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def get_by_id(user_id):
        sb = get_supabase()
        result = sb.table('users').select('*').eq('id', user_id).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def create(user_data):
        sb = get_supabase()
        result = sb.table('users').insert(user_data).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def update(user_id, update_data):
        sb = get_supabase()
        result = sb.table('users').update(update_data).eq('id', user_id).execute()
        return result.data[0] if result.data else None

class LostItemModel:
    @staticmethod
    def get_approved():
        sb = get_supabase()
        result = sb.table('lost_items').select('*').eq('is_approved', True).eq('is_found', False).order('created_at', desc=True).execute()
        return result.data
    
    @staticmethod
    def get_pending():
        sb = get_supabase()
        result = sb.table('lost_items').select('*').eq('is_approved', False).order('created_at', desc=True).execute()
        return result.data
    
    @staticmethod
    def get_by_id(item_id):
        sb = get_supabase()
        result = sb.table('lost_items').select('*').eq('id', item_id).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def create(item_data):
        sb = get_supabase()
        result = sb.table('lost_items').insert(item_data).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def update(item_id, update_data):
        sb = get_supabase()
        result = sb.table('lost_items').update(update_data).eq('id', item_id).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def search(query):
        sb = get_supabase()
        result = sb.table('lost_items').select('*').eq('is_approved', True).ilike('description', f'%{query}%').execute()
        return result.data

class FoundItemModel:
    @staticmethod
    def get_all():
        sb = get_supabase()
        result = sb.table('found_items').select('*').order('created_at', desc=True).execute()
        return result.data
    
    @staticmethod
    def create(item_data):
        sb = get_supabase()
        result = sb.table('found_items').insert(item_data).execute()
        return result.data[0] if result.data else None

class MessageModel:
    @staticmethod
    def get_between_users(user1, user2):
        sb = get_supabase()
        result = sb.table('messages').select('*').or_(
            f'and(author_id.eq.{user1},receiver_id.eq.{user2}),and(author_id.eq.{user2},receiver_id.eq.{user1})'
        ).order('created_at', desc=True).execute()
        return result.data
    
    @staticmethod
    def create(message_data):
        sb = get_supabase()
        result = sb.table('messages').insert(message_data).execute()
        return result.data[0] if result.data else None
    
    @staticmethod
    def mark_as_read(author_id, receiver_id):
        sb = get_supabase()
        sb.table('messages').update({
            'is_read': True,
            'read_at': datetime.utcnow().isoformat()
        }).eq('author_id', author_id).eq('receiver_id', receiver_id).eq('is_read', False).execute()
    
    @staticmethod
    def get_unread_count(user_id):
        sb = get_supabase()
        result = sb.table('messages').select('id', count='exact').eq('receiver_id', user_id).eq('is_read', False).execute()
        return result.count
    
    @staticmethod
    def get_chats_for_user(user_id):
        sb = get_supabase()
        
        result = sb.table('messages').select('*').or_(
            f'author_id.eq.{user_id},receiver_id.eq.{user_id}'
        ).order('created_at', desc=True).execute()
        
        if not result.data:
            return []
        
        chats = {}
        for msg in result.data:
            partner = msg['receiver_id'] if msg['author_id'] == user_id else msg['author_id']
            
            if partner not in chats:
                partner_user = UserModel.get_by_email(partner)
                chats[partner] = {
                    'chat_id': partner,
                    'user_name': partner_user['name'] if partner_user else partner.split('@')[0],
                    'latest_message': msg['text'],
                    'latest_message_time': msg['created_at'],
                    'unread_count': 0
                }
            
            if msg['author_id'] == partner and msg['receiver_id'] == user_id and not msg['is_read']:
                chats[partner]['unread_count'] += 1
        
        return list(chats.values())
