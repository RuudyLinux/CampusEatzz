-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Apr 12, 2026 at 12:25 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

CREATE DATABASE universitycanteendb;
USE universitycanteendb;
-- Table structure for table admin_users
--

CREATE TABLE admin_users (
  id int(11) NOT NULL,
  name varchar(100) NOT NULL,
  email varchar(150) NOT NULL,
  password varchar(255) NOT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table admin_users
--

INSERT INTO admin_users (id, name, email, password, created_at) VALUES
(1, 'Admin User', 'admin@gmail.com', '$2a$11$kvbuGQCViY5gsmhKLCAWBOs8wqL73/xyHsAYvyVaH8Nbw3teEXEfC', '2026-04-12 01:56:58'),
(2, 'Admin User', 'admin@utu.ac.in', '$2a$11$JnoH4jOOSlVvDLQ0m6bfu.zWY54589Vhvv9WJX94NBCVYaqa9EXs.', '2026-04-12 04:51:21');

-- --------------------------------------------------------

--
-- Table structure for table canteens
--

CREATE TABLE canteens (
  id int(11) NOT NULL,
  name varchar(255) NOT NULL,
  description text DEFAULT NULL,
  image_url varchar(255) DEFAULT NULL,
  status enum('active','deactive') NOT NULL DEFAULT 'active',
  display_order int(11) DEFAULT 0,
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table canteens
--

INSERT INTO canteens (id, name, description, image_url, status, display_order, created_at) VALUES
(1, 'Chirag Tea Center', 'Traditional tea and snacks', 'uploads/canteens/canteen_1775932340139_1e798d744aea4feeac5c805b9ce66fec.jpg', 'active', 0, '2025-11-22 14:06:53'),
(2, 'Tea Post', 'Quick bites and beverages', 'uploads/canteens/canteen_1775929424276_343815b680f647cc9b10d233cfde0bfe.jpg', 'active', 0, '2025-11-22 14:06:53'),
(3, 'Foodies', 'Delicious variety of food items', NULL, 'active', 3, '2025-11-22 14:06:53');

-- --------------------------------------------------------

--
-- Table structure for table canteen_admins
--

CREATE TABLE canteen_admins (
  id int(11) NOT NULL,
  canteen_id int(11) NOT NULL,
  username varchar(50) NOT NULL,
  password varchar(255) NOT NULL,
  plain_password varchar(255) DEFAULT NULL,
  name varchar(100) NOT NULL,
  email varchar(100) DEFAULT NULL,
  contact varchar(15) DEFAULT NULL,
  status enum('active','inactive') DEFAULT 'active',
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  image_url varchar(500) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table canteen_admins
--

INSERT INTO canteen_admins (id, canteen_id, username, password, plain_password, name, email, contact, status, created_at, updated_at, image_url) VALUES
(1, 1, 'chirag_admin', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'admin123', 'Chirag Admin', 'chirag@teatcenter.com', '9876543210', 'active', '2025-11-22 11:42:34', '2026-04-11 12:44:55', 'http://127.0.0.1:5266/uploads/canteens/canteen_1775929654700_56423e1cd6e940bab8a1ee48ee9507f6.jpg'),
(2, 2, 'teapost_admin', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'admin123', 'TeaPost Admin', 'admin@teapost.com', '9876543211', 'active', '2025-11-22 11:42:34', '2025-11-22 12:36:38', NULL),
(3, 3, 'foodies_admin', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'admin123', 'Foodies Admin', 'admin@foodies.com', '9876543212', 'active', '2025-11-22 11:42:34', '2025-11-22 12:36:38', NULL);

-- --------------------------------------------------------

--
-- Table structure for table cart_items
--

CREATE TABLE cart_items (
  CartItemId int(11) NOT NULL,
  UserId int(11) NOT NULL,
  CanteenId int(11) NOT NULL,
  MenuItemId int(11) NOT NULL,
  Quantity int(11) DEFAULT 1,
  AddedAt timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table contact_messages
--

CREATE TABLE contact_messages (
  id int(11) NOT NULL,
  name varchar(255) NOT NULL,
  email varchar(255) NOT NULL,
  subject varchar(255) NOT NULL,
  message text NOT NULL,
  status enum('unread','read','replied') DEFAULT 'unread',
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  replied_at timestamp NULL DEFAULT NULL,
  reply_message text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table maintenance_mode
--

CREATE TABLE maintenance_mode (
  id int(11) NOT NULL,
  canteen_id int(11) NOT NULL,
  is_active tinyint(1) DEFAULT 0,
  reason text DEFAULT NULL,
  started_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table maintenance_mode
--

INSERT INTO maintenance_mode (id, canteen_id, is_active, reason, started_at, updated_at) VALUES
(1, 1, 0, 'Canteen maintenance test', '2026-04-11 10:07:19', '2026-04-11 10:55:51'),
(2, 2, 0, '', '2026-04-11 10:22:17', '2026-04-11 10:23:02');

-- --------------------------------------------------------

--
-- Table structure for table menu_categories
--

CREATE TABLE menu_categories (
  id int(11) NOT NULL,
  name varchar(100) NOT NULL,
  description text DEFAULT NULL,
  display_order int(11) DEFAULT 0,
  is_active tinyint(1) DEFAULT 1,
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table menu_categories
--

INSERT INTO menu_categories (id, name, description, display_order, is_active, created_at) VALUES
(1, 'Burgers', 'Delicious burgers made fresh', 1, 1, '2025-11-22 13:28:06'),
(2, 'Pizzas', 'Wood-fired pizzas with premium toppings', 2, 1, '2025-11-22 13:28:06'),
(3, 'Salads', 'Fresh and healthy salads', 3, 1, '2025-11-22 13:28:06'),
(4, 'Beverages', 'Refreshing drinks and smoothies', 4, 1, '2025-11-22 13:28:06'),
(5, 'Desserts', 'Sweet treats to end your meal', 5, 1, '2025-11-22 13:28:06');

-- --------------------------------------------------------

--
-- Table structure for table menu_items
--

CREATE TABLE menu_items (
  id int(11) NOT NULL,
  category_id int(11) NOT NULL,
  canteen_id int(11) DEFAULT NULL,
  name varchar(255) NOT NULL,
  description text DEFAULT NULL,
  price decimal(10,2) NOT NULL,
  image_url varchar(500) DEFAULT NULL,
  is_available tinyint(1) DEFAULT 1,
  is_vegetarian tinyint(1) DEFAULT 0,
  spice_level enum('none','mild','medium','hot','extra_hot') DEFAULT 'none',
  preparation_time int(11) DEFAULT 15 COMMENT 'in minutes',
  display_order int(11) DEFAULT 0,
  is_deleted tinyint(1) NOT NULL DEFAULT 0,
  deleted_at timestamp NULL DEFAULT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table menu_items
--

INSERT INTO menu_items (id, category_id, canteen_id, name, description, price, image_url, is_available, is_vegetarian, spice_level, preparation_time, display_order, is_deleted, deleted_at, created_at, updated_at) VALUES
(1, 1, 1, 'Classic Burger', 'Juicy beef patty with lettuce, tomato, and special sauce', 249.00, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(2, 2, 1, 'Margherita Pizza', 'Classic pizza with fresh mozzarella and basil', 399.00, 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500', 1, 1, 'none', 20, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(3, 3, 1, 'Caesar Salad', 'Crisp romaine with caesar dressing and croutons', 229.00, 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=500', 1, 1, 'none', 10, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(4, 4, 1, 'Virgin Mojito', 'Refreshing mint and lime drink', 159.00, 'https://images.unsplash.com/photo-1551538827-9c037cb4f32a?w=500', 1, 1, 'none', 5, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(5, 4, 1, 'Tropical Smoothie', 'Blend of fresh tropical fruits', 179.00, 'https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=500', 1, 1, 'none', 7, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(6, 4, 2, 'Iced Latte', 'Chilled espresso with milk', 149.00, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=500', 1, 1, 'none', 5, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(7, 5, 1, 'Chocolate Brownie', 'Rich chocolate brownie with ice cream', 129.00, 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500', 1, 1, 'none', 5, 0, 0, NULL, '2025-11-22 13:28:06', '2025-11-22 14:07:34'),
(8, 1, 1, 'Cheese Burger', 'Juicy beef patty with melted cheddar cheese', 269.00, 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(9, 1, 2, 'Chicken Burger', 'Grilled chicken breast with lettuce and mayo', 289.00, 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(10, 1, 2, 'Veggie Burger', 'Plant-based patty with fresh vegetables', 239.00, 'https://images.unsplash.com/photo-1520072959219-c595dc870360?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(11, 1, 3, 'Bacon Burger', 'Classic burger with crispy bacon strips', 319.00, 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(12, 1, 3, 'Mushroom Swiss Burger', 'Topped with sautÚed mushrooms and Swiss cheese', 299.00, 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(13, 2, 1, 'Pepperoni Pizza', 'Classic pepperoni with mozzarella cheese', 429.00, 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(14, 2, 2, 'Veggie Supreme Pizza', 'Loaded with fresh vegetables', 379.00, 'https://images.unsplash.com/photo-1511689660979-10d2b1aada49?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(15, 2, 2, 'BBQ Chicken Pizza', 'BBQ sauce, grilled chicken, and onions', 449.00, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(16, 2, 3, 'Four Cheese Pizza', 'Mozzarella, cheddar, parmesan, and blue cheese', 419.00, 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(17, 2, 3, 'Hawaiian Pizza', 'Ham, pineapple, and cheese', 399.00, 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(18, 3, 1, 'Greek Salad', 'Feta cheese, olives, cucumber, tomatoes', 249.00, 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(19, 3, 2, 'Garden Salad', 'Fresh mixed greens with house dressing', 199.00, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(20, 3, 2, 'Chicken Caesar Salad', 'Grilled chicken with Caesar dressing', 279.00, 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=500', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(21, 3, 3, 'Asian Sesame Salad', 'Mixed greens with sesame ginger dressing', 259.00, 'https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(22, 3, 3, 'Caprese Salad', 'Fresh mozzarella, tomatoes, and basil', 269.00, 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(23, 4, 2, 'Fresh Orange Juice', 'Freshly squeezed orange juice', 129.00, 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(24, 4, 3, 'Mango Lassi', 'Traditional Indian mango yogurt drink', 139.00, 'https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(25, 4, 3, 'Cold Coffee', 'Chilled coffee with ice cream', 169.00, 'https://images.unsplash.com/photo-1517487881594-2787fef5ebf7?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(26, 5, 1, 'Tiramisu', 'Classic Italian coffee-flavored dessert', 169.00, 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(27, 5, 2, 'Cheesecake', 'New York style creamy cheesecake', 149.00, 'https://images.unsplash.com/photo-1533134486753-c833f0ed4866?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(28, 5, 2, 'Ice Cream Sundae', 'Vanilla ice cream with chocolate sauce', 119.00, 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(29, 5, 3, 'Apple Pie', 'Warm apple pie with cinnamon', 139.00, 'https://images.unsplash.com/photo-1535920527002-b35e96722eb9?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(30, 5, 3, 'Chocolate Mousse', 'Rich and creamy chocolate dessert', 159.00, 'https://images.unsplash.com/photo-1541599468348-e96984315921?w=500', 1, 1, 'none', 15, 0, 0, NULL, '2025-11-22 14:03:55', '2025-11-22 14:07:34'),
(35, 1, 1, 'tea', 'Masala Tea', 20.00, 'uploads/menu_items/item_6924721a654a2.jpg', 1, 0, 'none', 15, 0, 0, NULL, '2025-11-24 14:56:26', '2025-11-24 14:56:26');

-- --------------------------------------------------------

--
-- Table structure for table orders
--

CREATE TABLE orders (
  id int(11) NOT NULL,
  user_id int(11) NOT NULL,
  canteen_id int(11) DEFAULT NULL,
  order_number varchar(20) NOT NULL,
  customer_name varchar(255) DEFAULT NULL,
  customer_phone varchar(15) DEFAULT NULL,
  delivery_address text DEFAULT NULL,
  order_type enum('dine_in','takeaway','delivery') DEFAULT 'dine_in',
  table_number varchar(10) DEFAULT NULL,
  total_amount decimal(10,2) NOT NULL DEFAULT 0.00,
  discount_amount decimal(10,2) DEFAULT 0.00,
  tax_amount decimal(10,2) DEFAULT 0.00,
  final_amount decimal(10,2) NOT NULL DEFAULT 0.00,
  payment_method enum('cash','card','upi','online') DEFAULT 'cash',
  payment_status enum('pending','paid','failed','refunded') DEFAULT 'pending',
  order_status enum('pending','confirmed','preparing','ready','completed','cancelled') DEFAULT 'pending',
  special_instructions text DEFAULT NULL,
  estimated_time int(11) DEFAULT NULL COMMENT 'in minutes',
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  completed_at timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table orders
--

INSERT INTO orders (id, user_id, canteen_id, order_number, customer_name, customer_phone, delivery_address, order_type, table_number, total_amount, discount_amount, tax_amount, final_amount, payment_method, payment_status, order_status, special_instructions, estimated_time, created_at, updated_at, completed_at) VALUES
(1, 5, NULL, 'FO260405211623791', 'Ayush Jain', NULL, NULL, 'takeaway', NULL, 20.00, 0.00, 1.00, 21.00, 'cash', 'pending', 'pending', NULL, NULL, '2026-04-05 15:46:23', '2026-04-05 15:46:23', NULL),
(2, 5, NULL, 'FO260405211639600', 'Ayush Jain', NULL, NULL, 'takeaway', NULL, 20.00, 0.00, 1.00, 21.00, 'cash', 'pending', 'pending', NULL, NULL, '2026-04-05 15:46:39', '2026-04-05 15:46:39', NULL),
(3, 5, 1, 'FO260407164617410', 'Ayush Jain', NULL, NULL, 'takeaway', NULL, 20.00, 0.00, 1.00, 21.00, 'cash', 'pending', 'confirmed', NULL, 20, '2026-04-07 11:16:17', '2026-04-07 11:49:19', NULL),
(4, 7, NULL, 'FO260407191645111', 'Rudra Gosvami', '9924891310', NULL, 'takeaway', NULL, 135.00, 0.00, 6.75, 141.75, 'cash', 'pending', 'pending', NULL, NULL, '2026-04-07 13:46:45', '2026-04-07 13:46:45', NULL),
(5, 7, NULL, 'FO260411145646700', 'Rudra Gosvami', '9924891310', NULL, 'takeaway', NULL, 40.00, 0.00, 2.00, 42.00, 'online', 'paid', 'pending', NULL, NULL, '2026-04-11 09:26:46', '2026-04-11 09:26:46', NULL);

-- --------------------------------------------------------

--
-- Table structure for table order_items
--

CREATE TABLE order_items (
  id int(11) NOT NULL,
  order_id int(11) NOT NULL,
  menu_item_id int(11) NOT NULL,
  item_name varchar(255) NOT NULL,
  quantity int(11) NOT NULL DEFAULT 1,
  unit_price decimal(10,2) NOT NULL,
  total_price decimal(10,2) NOT NULL,
  special_instructions text DEFAULT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table order_items
--

INSERT INTO order_items (id, order_id, menu_item_id, item_name, quantity, unit_price, total_price, special_instructions, created_at) VALUES
(1, 1, 1, 'Tea', 1, 20.00, 20.00, NULL, '2026-04-05 15:46:23'),
(2, 2, 1, 'Tea', 1, 20.00, 20.00, NULL, '2026-04-05 15:46:39'),
(3, 3, 1, 'Tea', 1, 20.00, 20.00, NULL, '2026-04-07 11:16:17'),
(4, 4, 1, 'Masala Tea', 1, 15.00, 15.00, NULL, '2026-04-07 13:46:45'),
(5, 4, 2, 'Veg Sandwich', 1, 40.00, 40.00, NULL, '2026-04-07 13:46:45'),
(6, 4, 4, 'Cheese Pizza', 1, 80.00, 80.00, NULL, '2026-04-07 13:46:45'),
(7, 5, 2, 'Veg Sandwich', 1, 40.00, 40.00, NULL, '2026-04-11 09:26:46');

-- --------------------------------------------------------

--
-- Table structure for table order_status_history
--

CREATE TABLE order_status_history (
  id int(11) NOT NULL,
  order_id int(11) NOT NULL,
  previous_status varchar(50) DEFAULT NULL,
  new_status varchar(50) NOT NULL,
  changed_by int(11) DEFAULT NULL,
  notes text DEFAULT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table order_status_history
--

INSERT INTO order_status_history (id, order_id, previous_status, new_status, changed_by, notes, created_at) VALUES
(1, 3, 'pending', 'confirmed', NULL, 'Smoke test status update', '2026-04-07 11:16:17'),
(2, 3, 'confirmed', 'confirmed', NULL, 'rbac smoke', '2026-04-07 11:49:19');

-- --------------------------------------------------------

--
-- Table structure for table reviews
--

CREATE TABLE reviews (
  id int(11) NOT NULL,
  user_id int(11) NOT NULL,
  canteen_id int(11) NOT NULL,
  order_id int(11) DEFAULT NULL,
  rating tinyint(1) NOT NULL CHECK (rating >= 1 and rating <= 5),
  review_text text NOT NULL,
  admin_response text DEFAULT NULL,
  response_date datetime DEFAULT NULL,
  status enum('active','hidden') DEFAULT 'active',
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table students
--

CREATE TABLE students (
  UniversityId varchar(50) NOT NULL,
  course varchar(100) NOT NULL,
  semester int(11) NOT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table students
--

INSERT INTO students (UniversityId, course, semester, created_at, updated_at) VALUES
('202307100110025', 'Computer Science', 1, '2026-04-05 19:00:23', '2026-04-05 19:00:23'),
('202307100110147', 'Computer Science', 1, '2026-04-05 19:00:23', '2026-04-05 19:00:23'),
('202307100110171', 'Computer Science', 1, '2026-04-05 19:00:23', '2026-04-05 19:00:23');

-- --------------------------------------------------------

--
-- Table structure for table system_settings
--

CREATE TABLE system_settings (
  id int(11) NOT NULL,
  setting_key varchar(100) NOT NULL,
  setting_value text DEFAULT NULL,
  description varchar(255) DEFAULT NULL,
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table system_settings
--

INSERT INTO system_settings (id, setting_key, setting_value, description, updated_at) VALUES
(7, 'app_name', 'CampusEatzz', 'Application name', '2026-04-12 07:09:37'),
(8, 'logo_url', '/uploads/logo.jpg', 'Website logo', '2026-04-12 07:09:54'),
(9, 'tax_percentage', '5', 'Tax percentage', '2026-04-12 07:09:37'),
(10, 'delivery_charge', '50', 'Delivery charge', '2026-04-12 07:09:37'),
(11, 'min_order_delivery', '200', 'Minimum order amount', '2026-04-12 07:09:37'),
(12, 'operating_hours_open', '09:00', 'Opening time', '2026-04-12 07:09:37'),
(13, 'operating_hours_close', '22:00', 'Closing time', '2026-04-12 07:09:37');

-- --------------------------------------------------------

--
-- Table structure for table university_staff
--

CREATE TABLE university_staff (
  UniversityId varchar(50) NOT NULL,
  department varchar(50) NOT NULL,
  DateOfBirth date NOT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table university_staff
--

INSERT INTO university_staff (UniversityId, department, DateOfBirth, created_at, updated_at) VALUES
('201', 'Computer Science', '1980-01-01', '2026-04-05 19:00:23', '2026-04-05 19:00:23');

-- --------------------------------------------------------

--
-- Table structure for table users
--

CREATE TABLE users (
  id int(11) NOT NULL,
  UniversityId varchar(50) DEFAULT NULL,
  first_name varchar(100) NOT NULL,
  last_name varchar(100) NOT NULL,
  email varchar(150) NOT NULL,
  contact varchar(15) NOT NULL,
  department varchar(100) NOT NULL,
  password_hash varchar(255) NOT NULL,
  role enum('student','admin','staff','canteen_admin') NOT NULL,
  canteen_id int(11) DEFAULT NULL,
  status enum('active','inactive','banned') DEFAULT 'active',
  is_deleted tinyint(1) NOT NULL DEFAULT 0,
  deleted_at timestamp NULL DEFAULT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  IsLoggedIn tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table users
--

INSERT INTO users (id, UniversityId, first_name, last_name, email, contact, department, password_hash, role, canteen_id, status, is_deleted, deleted_at, created_at, updated_at, IsLoggedIn) VALUES
(1, NULL, 'Admin', 'User', 'admin@utu.ac.in', '9876543200', 'Administration', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'admin', NULL, 'active', 0, NULL, '2025-11-22 00:00:00', '2026-04-12 08:12:54', 0),
(2, NULL, 'Chirag', 'Admin', 'chirag@teatcenter.com', '9876543210', 'Administration', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'canteen_admin', 1, 'active', 0, NULL, '2025-11-22 14:34:05', '2026-04-07 18:23:48', 0),
(3, NULL, 'TeaPost', 'Admin', 'admin@teapost.com', '9876543211', 'Administration', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'canteen_admin', 2, 'active', 0, NULL, '2025-11-22 14:34:05', '2025-11-22 14:48:26', 0),
(4, NULL, 'Foodies', 'Admin', 'admin@foodies.com', '9876543212', 'Administration', '$2y$12$6wYuPC0WFMgTj3t6xkt4Xuxo68EcYBWfTPvROQuB4JTQtsC7ry4WK', 'canteen_admin', 3, 'active', 0, NULL, '2025-11-22 14:34:05', '2025-11-22 14:48:26', 0),
(5, '202307100110147', 'Ayush', 'Jain', '23bmii147@gmail.com', '9876500147', 'Computer Science', '$2a$11$SK./ZA9fON3hseSttJcqAOy6s39l/uydHRFz.wmQ1fsRg2iKV5KZ.', 'student', NULL, 'active', 0, NULL, '2026-04-04 13:57:00', '2026-04-04 13:57:00', 0),
(6, '202307100110171', 'Helly', 'Lankapti', '23bmii171@gmail.com', '9876500171', 'Computer Science', '$2a$11$SK./ZA9fON3hseSttJcqAOy6s39l/uydHRFz.wmQ1fsRg2iKV5KZ.', 'student', NULL, 'active', 0, NULL, '2026-04-04 13:57:00', '2026-04-04 13:57:00', 0),
(7, '202307100110025', 'Rudra', 'Gosvami', '23bmiit025@gmail.com', '9924891310', 'Computer Science', '$2a$11$SK./ZA9fON3hseSttJcqAOy6s39l/uydHRFz.wmQ1fsRg2iKV5KZ.', 'student', NULL, 'active', 0, NULL, '2026-04-04 13:57:00', '2026-04-11 18:31:44', 1),
(8, '201', 'Ayman', 'Shekh', 'ayman.shekh@utu.ac.in', '9876500201', 'Computer Science', '$2a$11$SK./ZA9fON3hseSttJcqAOy6s39l/uydHRFz.wmQ1fsRg2iKV5KZ.', 'staff', NULL, 'active', 0, NULL, '2026-04-04 13:57:00', '2026-04-04 13:57:00', 0);

-- --------------------------------------------------------

--
-- Table structure for table wallets
--

CREATE TABLE wallets (
  id int(11) NOT NULL,
  user_id int(11) NOT NULL,
  balance decimal(10,2) DEFAULT 0.00,
  created_at timestamp NOT NULL DEFAULT current_timestamp(),
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table wallets
--

INSERT INTO wallets (id, user_id, balance, created_at, updated_at) VALUES
(1, 5, 20.00, '2026-04-05 21:16:23', '2026-04-05 21:16:39'),
(10, 8, 0.00, '2026-04-07 16:46:17', '2026-04-07 16:46:17'),
(11, 7, 858.00, '2026-04-07 16:46:17', '2026-04-11 14:56:46'),
(12, 6, 0.00, '2026-04-07 16:46:17', '2026-04-07 16:46:17'),
(14, 4, 0.00, '2026-04-07 16:46:17', '2026-04-07 16:46:17'),
(15, 3, 0.00, '2026-04-07 16:46:17', '2026-04-07 16:46:17'),
(16, 2, 0.00, '2026-04-07 16:46:17', '2026-04-07 16:46:17'),
(17, 1, 0.00, '2026-04-07 16:46:17', '2026-04-07 16:46:17');

-- --------------------------------------------------------

--
-- Table structure for table wallet_transactions
--

CREATE TABLE wallet_transactions (
  id int(11) NOT NULL,
  user_id int(11) NOT NULL,
  transaction_id varchar(100) NOT NULL,
  amount decimal(10,2) NOT NULL,
  type enum('credit','debit') NOT NULL,
  status enum('pending','completed','failed','refunded') DEFAULT 'pending',
  payment_gateway varchar(50) DEFAULT NULL,
  gateway_order_id varchar(100) DEFAULT NULL,
  gateway_payment_id varchar(100) DEFAULT NULL,
  gateway_signature varchar(255) DEFAULT NULL,
  description text DEFAULT NULL,
  order_id int(11) DEFAULT NULL,
  created_at timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table wallet_transactions
--

INSERT INTO wallet_transactions (id, user_id, transaction_id, amount, type, status, payment_gateway, gateway_order_id, gateway_payment_id, gateway_signature, description, order_id, created_at) VALUES
(1, 5, 'CR202604052116239862', 10.00, 'credit', 'completed', 'smoke-test', NULL, NULL, NULL, 'Smoke test recharge', NULL, '2026-04-05 15:46:23'),
(2, 5, 'CR202604052116393833', 10.00, 'credit', 'completed', 'smoke-test', NULL, NULL, NULL, 'Smoke test recharge', NULL, '2026-04-05 15:46:39'),
(3, 7, 'CR202604071921242193', 100.00, 'credit', 'completed', 'wallet-page', NULL, NULL, NULL, 'Wallet recharge from wallet page', NULL, '2026-04-07 13:51:24'),
(4, 7, 'CR202604071921391350', 200.00, 'credit', 'completed', 'wallet-page', NULL, NULL, NULL, 'Wallet recharge from wallet page', NULL, '2026-04-07 13:51:39'),
(5, 7, 'CR202604072103342267', 100.00, 'credit', 'completed', 'wallet-page', NULL, NULL, NULL, 'Wallet recharge from wallet page', NULL, '2026-04-07 15:33:34'),
(6, 7, 'CR202604072114266351', 500.00, 'credit', 'completed', 'wallet-page', NULL, NULL, NULL, 'Wallet recharge from wallet page', NULL, '2026-04-07 15:44:26'),
(7, 7, 'DB202604111456464080', 42.00, 'debit', 'completed', 'wallet', NULL, NULL, NULL, 'Order payment - FO260411145646700', 5, '2026-04-11 09:26:46');

-- --------------------------------------------------------

--
-- Table structure for table website_maintenance
--

CREATE TABLE website_maintenance (
  id int(11) NOT NULL,
  is_active tinyint(1) DEFAULT 0,
  maintenance_message text DEFAULT 'We are currently performing maintenance. Please check back soon.',
  updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table website_maintenance
--

INSERT INTO website_maintenance (id, is_active, maintenance_message, updated_at) VALUES
(1, 0, 'We are currently performing maintenance. Please check back soon.', '2026-04-11 16:43:07');

--
-- Indexes for dumped tables
--

--
-- Indexes for table admin_users
--
ALTER TABLE admin_users
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY uq_admin_users_email (email);

--
-- Indexes for table canteens
--
ALTER TABLE canteens
  ADD PRIMARY KEY (id),
  ADD KEY idx_canteens_status (status);

--
-- Indexes for table canteen_admins
--
ALTER TABLE canteen_admins
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY username (username),
  ADD KEY canteen_id (canteen_id),
  ADD KEY status (status);

--
-- Indexes for table cart_items
--
ALTER TABLE cart_items
  ADD PRIMARY KEY (CartItemId),
  ADD UNIQUE KEY uq_cart_user_canteen_item (UserId,CanteenId,MenuItemId),
  ADD KEY UserId (UserId),
  ADD KEY CanteenId (CanteenId),
  ADD KEY MenuItemId (MenuItemId);

--
-- Indexes for table contact_messages
--
ALTER TABLE contact_messages
  ADD PRIMARY KEY (id),
  ADD KEY idx_status (status);

--
-- Indexes for table maintenance_mode
--
ALTER TABLE maintenance_mode
  ADD PRIMARY KEY (id),
  ADD KEY canteen_id (canteen_id);

--
-- Indexes for table menu_categories
--
ALTER TABLE menu_categories
  ADD PRIMARY KEY (id),
  ADD KEY idx_active (is_active);

--
-- Indexes for table menu_items
--
ALTER TABLE menu_items
  ADD PRIMARY KEY (id),
  ADD KEY category_id (category_id),
  ADD KEY idx_available (is_available),
  ADD KEY canteen_id (canteen_id),
  ADD KEY idx_menu_name (name),
  ADD KEY idx_menu_items_soft_delete (is_deleted);

--
-- Indexes for table orders
--
ALTER TABLE orders
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY order_number (order_number),
  ADD KEY user_id (user_id),
  ADD KEY canteen_id (canteen_id),
  ADD KEY idx_status (order_status),
  ADD KEY idx_payment_status (payment_status),
  ADD KEY idx_created_at (created_at);

--
-- Indexes for table order_items
--
ALTER TABLE order_items
  ADD PRIMARY KEY (id),
  ADD KEY order_id (order_id),
  ADD KEY menu_item_id (menu_item_id);

--
-- Indexes for table order_status_history
--
ALTER TABLE order_status_history
  ADD PRIMARY KEY (id),
  ADD KEY order_id (order_id),
  ADD KEY changed_by (changed_by);

--
-- Indexes for table reviews
--
ALTER TABLE reviews
  ADD PRIMARY KEY (id),
  ADD KEY user_id (user_id),
  ADD KEY canteen_id (canteen_id),
  ADD KEY order_id (order_id),
  ADD KEY rating (rating),
  ADD KEY status (status);

-- Indexes for table students
--
ALTER TABLE students
  ADD PRIMARY KEY (UniversityId),
  ADD KEY idx_students_course (course),
  ADD KEY idx_students_semester (semester);

--
-- Indexes for table system_settings
--
ALTER TABLE system_settings
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY setting_key (setting_key);

--
-- Indexes for table university_staff
--
ALTER TABLE university_staff
  ADD PRIMARY KEY (UniversityId),
  ADD KEY idx_staff_department (department),
  ADD KEY idx_staff_dob (DateOfBirth);

--
-- Indexes for table users
--
ALTER TABLE users
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY email (email),
  ADD UNIQUE KEY UniversityId (UniversityId),
  ADD KEY idx_role (role),
  ADD KEY idx_status (status),
  ADD KEY idx_users_canteen_id (canteen_id),
  ADD KEY idx_users_soft_delete (is_deleted);

--
-- Indexes for table wallets
--
ALTER TABLE wallets
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY user_id (user_id);

--
-- Indexes for table wallet_transactions
--
ALTER TABLE wallet_transactions
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY transaction_id (transaction_id),
  ADD KEY user_id (user_id),
  ADD KEY order_id (order_id);

--
-- Indexes for table website_maintenance
--
ALTER TABLE website_maintenance
  ADD PRIMARY KEY (id);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table admin_users
--
ALTER TABLE admin_users
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table canteens
--
ALTER TABLE canteens
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table canteen_admins
--
ALTER TABLE canteen_admins
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table cart_items
--
ALTER TABLE cart_items
  MODIFY CartItemId int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table contact_messages
--
ALTER TABLE contact_messages
  MODIFY id int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table maintenance_mode
--
ALTER TABLE maintenance_mode
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table menu_categories
--
ALTER TABLE menu_categories
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table menu_items
--
ALTER TABLE menu_items
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table orders
--
ALTER TABLE orders
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table order_items
--
ALTER TABLE order_items
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table order_status_history
--
ALTER TABLE order_status_history
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table reviews
--
ALTER TABLE reviews
  MODIFY id int(11) NOT NULL AUTO_INCREMENT;

-- AUTO_INCREMENT for table system_settings
--
ALTER TABLE system_settings
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table users
--
ALTER TABLE users
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table wallets
--
ALTER TABLE wallets
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=409;

--
-- AUTO_INCREMENT for table wallet_transactions
--
ALTER TABLE wallet_transactions
  MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- Constraints for dumped tables
--

--
-- Constraints for table canteen_admins
--
ALTER TABLE canteen_admins
  ADD CONSTRAINT canteen_admins_ibfk_1 FOREIGN KEY (canteen_id) REFERENCES canteens (id) ON DELETE CASCADE;

--
-- Constraints for table cart_items
--
ALTER TABLE cart_items
  ADD CONSTRAINT cart_items_ibfk_1 FOREIGN KEY (UserId) REFERENCES users (id) ON DELETE CASCADE,
  ADD CONSTRAINT cart_items_ibfk_2 FOREIGN KEY (CanteenId) REFERENCES canteens (id) ON DELETE CASCADE,
  ADD CONSTRAINT cart_items_ibfk_3 FOREIGN KEY (MenuItemId) REFERENCES menu_items (id) ON DELETE CASCADE;

--
-- Constraints for table maintenance_mode
--
ALTER TABLE maintenance_mode
  ADD CONSTRAINT fk_maintenance_canteen FOREIGN KEY (canteen_id) REFERENCES canteens (id) ON DELETE CASCADE;

--
-- Constraints for table menu_items
--
ALTER TABLE menu_items
  ADD CONSTRAINT menu_items_ibfk_1 FOREIGN KEY (category_id) REFERENCES menu_categories (id) ON DELETE CASCADE,
  ADD CONSTRAINT menu_items_ibfk_2 FOREIGN KEY (canteen_id) REFERENCES canteens (id) ON DELETE SET NULL;

--
-- Constraints for table orders
--
ALTER TABLE orders
  ADD CONSTRAINT orders_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  ADD CONSTRAINT orders_ibfk_2 FOREIGN KEY (canteen_id) REFERENCES canteens (id) ON DELETE SET NULL;

--
-- Constraints for table order_items
--
ALTER TABLE order_items
  ADD CONSTRAINT order_items_ibfk_1 FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  ADD CONSTRAINT order_items_ibfk_2 FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE;

--
-- Constraints for table order_status_history
--
ALTER TABLE order_status_history
  ADD CONSTRAINT order_status_history_ibfk_1 FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  ADD CONSTRAINT order_status_history_ibfk_2 FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL;

--
-- Constraints for table reviews
--
ALTER TABLE reviews
  ADD CONSTRAINT reviews_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  ADD CONSTRAINT reviews_ibfk_2 FOREIGN KEY (canteen_id) REFERENCES canteens (id) ON DELETE CASCADE,
  ADD CONSTRAINT reviews_ibfk_3 FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE SET NULL;

--
-- Constraints for table students
--
ALTER TABLE students
  ADD CONSTRAINT fk_student_user FOREIGN KEY (UniversityId) REFERENCES users (UniversityId) ON DELETE CASCADE;

--
-- Constraints for table university_staff
--
ALTER TABLE university_staff
  ADD CONSTRAINT fk_university_staff_user FOREIGN KEY (UniversityId) REFERENCES users (UniversityId) ON DELETE CASCADE;

--
-- Constraints for table users
--
ALTER TABLE users
  ADD CONSTRAINT fk_users_canteen FOREIGN KEY (canteen_id) REFERENCES canteens (id) ON DELETE SET NULL;

--
-- Constraints for table wallets
--
ALTER TABLE wallets
  ADD CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;

--
-- Constraints for table wallet_transactions
--
ALTER TABLE wallet_transactions
  ADD CONSTRAINT fk_wallet_transaction_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_wallet_transaction_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
