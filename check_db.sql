-- Check menu items count
SELECT 'Menu Items Count:' as info, COUNT(*) as count FROM menu_items;

-- Check items by canteen
SELECT 'Items by Canteen:' as info, canteen_id, COUNT(*) as count FROM menu_items WHERE is_deleted = 0 GROUP BY canteen_id;

-- Check canteen names
SELECT 'Canteens:' as info, id, name FROM canteens WHERE status = 'active';

-- Check first 5 menu items
SELECT 'Sample Menu Items:' as info, id, canteen_id, name FROM menu_items LIMIT 5;
