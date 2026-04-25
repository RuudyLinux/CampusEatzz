-- Step 1: Soft delete all existing menu items (mark as deleted)
UPDATE menu_items SET is_deleted = 1 WHERE COALESCE(is_deleted, 0) = 0;

-- Step 2: Add menu items for Chirag Tea Center (ID: 1)
-- Caesar_Salad
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (1, 1, 'Caesar Salad', 'Fresh crisp romaine lettuce with parmesan and Caesar dressing', 150.00, '/uploads/menu_items/Caesar_Salad.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Continental_Breakfast
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (1, 2, 'Continental Breakfast', 'Eggs, toast, bacon, and fresh juice', 200.00, '/uploads/menu_items/Continental_Breakfast.jpg', 1, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Fish_&_Chips
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (1, 3, 'Fish & Chips', 'Crispy battered fish with golden fries', 220.00, '/uploads/menu_items/Fish_&_Chips.jpg', 1, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Gulab_Jamun
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (1, 4, 'Gulab Jamun', 'Sweet milk solids soaked in sugar syrup', 80.00, '/uploads/menu_items/Gulab_Jamun.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Iced_Latte
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (1, 5, 'Iced Latte', 'Cold espresso with steamed milk and ice', 120.00, '/uploads/menu_items/Iced_Latte.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Margherita_Pizza
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (1, 3, 'Margherita Pizza', 'Classic pizza with mozzarella, tomato, and basil', 250.00, '/uploads/menu_items/Margherita_Pizza.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Step 3: Add menu items for Foodies (ID: 3)
-- Mushroom_Stroganoff
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 3, 'Mushroom Stroganoff', 'Creamy mushroom sauce with tender pasta', 280.00, '/uploads/menu_items/Mushroom_Stroganoff.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Nachos_Supreme
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 1, 'Nachos Supreme', 'Crispy nachos with cheese, jalapeños, and sour cream', 200.00, '/uploads/menu_items/Nachos_Supreme.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- New_York_Cheesecake
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 4, 'New York Cheesecake', 'Classic creamy cheesecake with graham cracker crust', 150.00, '/uploads/menu_items/New_York_Cheesecake.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Pancakes_Stack
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 2, 'Pancakes Stack', 'Fluffy pancakes with butter and maple syrup', 180.00, '/uploads/menu_items/Pancakes_Stack.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Paneer_Tikka_Masala
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 1, 'Paneer Tikka Masala', 'Soft paneer in creamy tomato sauce', 240.00, '/uploads/menu_items/Paneer_Tikka_Masala.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Pasta_Alfredo
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 3, 'Pasta Alfredo', 'Creamy Alfredo sauce with fresh parmesan', 220.00, '/uploads/menu_items/Pasta_Alfredo.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Penne_Arrabiata
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (3, 3, 'Penne Arrabiata', 'Spicy tomato and garlic pasta', 210.00, '/uploads/menu_items/Penne_Arrabiata.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Step 4: Add menu items for Tea Post (ID: 2)
-- Pepperoni_Pizza
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 3, 'Pepperoni Pizza', 'Pizza with pepperoni and mozzarella cheese', 260.00, '/uploads/menu_items/Pepperoni_Pizza.jpg', 1, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Restaurants (keeping as is based on user request)
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 1, 'Restaurants', 'Our partner restaurants menu', 0.00, '/uploads/menu_items/Restaurants.jpg', 1, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Scrambled_Eggs
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 2, 'Scrambled Eggs', 'Fluffy scrambled eggs with toast', 120.00, '/uploads/menu_items/Scrambled_Eggs.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Spring_Rolls
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 1, 'Spring Rolls', 'Crispy vegetable spring rolls with dipping sauce', 100.00, '/uploads/menu_items/Spring_Rolls.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Tropical_Smoothie
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 5, 'Tropical Smoothie', 'Fresh mango and pineapple smoothie', 110.00, '/uploads/menu_items/Tropical_Smoothie.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Vegetable_Biryani
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 1, 'Vegetable Biryani', 'Aromatic basmati rice with mixed vegetables', 180.00, '/uploads/menu_items/Vegetable_Biryani.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Virgin_Mojito
INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
VALUES (2, 5, 'Virgin Mojito', 'Refreshing mint and lime mocktail', 100.00, '/uploads/menu_items/Virgin_Mojito.jpg', 1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP());

-- Verify the changes
SELECT canteen_id, COUNT(*) as item_count FROM menu_items WHERE is_deleted = 0 GROUP BY canteen_id;
