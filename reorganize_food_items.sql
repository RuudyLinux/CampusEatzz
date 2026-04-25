-- Get canteen IDs
SELECT id, name FROM canteens WHERE status = 'active';

-- Check current menu items
SELECT id, canteen_id, name, is_deleted FROM menu_items LIMIT 10;
