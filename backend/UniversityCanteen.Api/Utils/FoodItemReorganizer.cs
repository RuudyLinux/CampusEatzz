using Dapper;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Utils;

public sealed class FoodItemReorganizer
{
    private readonly IDbConnectionFactory _dbConnectionFactory;

    public FoodItemReorganizer(IDbConnectionFactory dbConnectionFactory)
    {
        _dbConnectionFactory = dbConnectionFactory;
    }

    public async Task<ReorganizationResult> ReorganizeFoodItemsAsync(CancellationToken cancellationToken = default)
    {
        var result = new ReorganizationResult();

        try
        {
            using var connection = _dbConnectionFactory.CreateConnection();

            // Step 1: Soft delete all existing menu items
            var deletedCount = await connection.ExecuteAsync(
                "UPDATE menu_items SET is_deleted = 1 WHERE COALESCE(is_deleted, 0) = 0;");
            result.DeletedItemsCount = deletedCount;

            // Step 2: Add items for Chirag Tea Center (ID: 1)
            var chiragItems = new[]
            {
                (3, "Caesar Salad", "Fresh crisp romaine lettuce with parmesan and Caesar dressing", 150.00, "/uploads/menu_items/Caesar_Salad.jpg", 1, 1),
                (3, "Continental Breakfast", "Eggs, toast, bacon, and fresh juice", 200.00, "/uploads/menu_items/Continental_Breakfast.jpg", 1, 0),
                (3, "Fish & Chips", "Crispy battered fish with golden fries", 220.00, "/uploads/menu_items/Fish_&_Chips.jpg", 1, 0),
                (5, "Gulab Jamun", "Sweet milk solids soaked in sugar syrup", 80.00, "/uploads/menu_items/Gulab_Jamun.jpg", 1, 1),
                (4, "Iced Latte", "Cold espresso with steamed milk and ice", 120.00, "/uploads/menu_items/Iced_Latte.jpg", 1, 1),
                (2, "Margherita Pizza", "Classic pizza with mozzarella, tomato, and basil", 250.00, "/uploads/menu_items/Margherita_Pizza.jpg", 1, 1),
            };

            var chiragCount = await InsertMenuItemsAsync(connection, 1, chiragItems);
            result.ChiragTeaCenterCount = chiragCount;

            // Step 3: Add items for Foodies (ID: 3)
            var foodiesItems = new[]
            {
                (3, "Mushroom Stroganoff", "Creamy mushroom sauce with tender pasta", 280.00, "/uploads/menu_items/Mushroom_Stroganoff.jpg", 1, 1),
                (3, "Nachos Supreme", "Crispy nachos with cheese, jalapeños, and sour cream", 200.00, "/uploads/menu_items/Nachos_Supreme.jpg", 1, 1),
                (5, "New York Cheesecake", "Classic creamy cheesecake with graham cracker crust", 150.00, "/uploads/menu_items/New_York_Cheesecake.jpg", 1, 1),
                (3, "Pancakes Stack", "Fluffy pancakes with butter and maple syrup", 180.00, "/uploads/menu_items/Pancakes_Stack.jpg", 1, 1),
                (3, "Paneer Tikka Masala", "Soft paneer in creamy tomato sauce", 240.00, "/uploads/menu_items/Paneer_Tikka_Masala.jpg", 1, 1),
                (3, "Pasta Alfredo", "Creamy Alfredo sauce with fresh parmesan", 220.00, "/uploads/menu_items/Pasta_Alfredo.jpg", 1, 1),
                (3, "Penne Arrabiata", "Spicy tomato and garlic pasta", 210.00, "/uploads/menu_items/Penne_Arrabiata.jpg", 1, 1),
            };

            var foodiesCount = await InsertMenuItemsAsync(connection, 3, foodiesItems);
            result.FoodiesCount = foodiesCount;

            // Step 4: Add items for Tea Post (ID: 2)
            var teaPostItems = new[]
            {
                (2, "Pepperoni Pizza", "Pizza with pepperoni and mozzarella cheese", 260.00, "/uploads/menu_items/Pepperoni_Pizza.jpg", 1, 0),
                (3, "Restaurants", "Our partner restaurants menu", 0.00, "/uploads/menu_items/Restaurants.jpg", 1, 0),
                (3, "Scrambled Eggs", "Fluffy scrambled eggs with toast", 120.00, "/uploads/menu_items/Scrambled_Eggs.jpg", 1, 1),
                (3, "Spring Rolls", "Crispy vegetable spring rolls with dipping sauce", 100.00, "/uploads/menu_items/Spring_Rolls.jpg", 1, 1),
                (4, "Tropical Smoothie", "Fresh mango and pineapple smoothie", 110.00, "/uploads/menu_items/Tropical_Smoothie.jpg", 1, 1),
                (3, "Vegetable Biryani", "Aromatic basmati rice with mixed vegetables", 180.00, "/uploads/menu_items/Vegetable_Biryani.jpg", 1, 1),
                (4, "Virgin Mojito", "Refreshing mint and lime mocktail", 100.00, "/uploads/menu_items/Virgin_Mojito.jpg", 1, 1),
            };

            var teaPostCount = await InsertMenuItemsAsync(connection, 2, teaPostItems);
            result.TeaPostCount = teaPostCount;

            result.Success = true;
            result.Message = "Food items reorganized successfully";
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Message = $"Error during reorganization: {ex.Message}";
        }

        return result;
    }

    private async Task<int> InsertMenuItemsAsync(
        System.Data.IDbConnection connection,
        int canteenId,
        (int categoryId, string name, string description, double price, string imageUrl, int isAvailable, int isVegetarian)[] items)
    {
        int count = 0;
        foreach (var item in items)
        {
            try
            {
                await connection.ExecuteAsync(
                    """
                    INSERT INTO menu_items (category_id, canteen_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
                    VALUES (@categoryId, @canteenId, @name, @description, @price, @imageUrl, @isAvailable, @isVegetarian, UTC_TIMESTAMP(), UTC_TIMESTAMP());
                    """,
                    new
                    {
                        categoryId = item.categoryId,
                        canteenId,
                        name = item.name,
                        description = item.description,
                        price = item.price,
                        imageUrl = item.imageUrl,
                        isAvailable = item.isAvailable,
                        isVegetarian = item.isVegetarian
                    });
                count++;
            }
            catch (Exception ex)
            {
                System.Console.WriteLine($"Failed to insert {item.name} for canteen {canteenId}: {ex.Message}");
                // Continue with next item if insertion fails
            }
        }
        return count;
    }
}

public sealed class ReorganizationResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public int DeletedItemsCount { get; set; }
    public int ChiragTeaCenterCount { get; set; }
    public int FoodiesCount { get; set; }
    public int TeaPostCount { get; set; }

    public int TotalNewItems => ChiragTeaCenterCount + FoodiesCount + TeaPostCount;
}
