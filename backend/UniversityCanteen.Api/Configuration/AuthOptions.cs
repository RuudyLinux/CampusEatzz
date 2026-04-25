namespace UniversityCanteen.Api.Configuration;

public sealed class AuthOptions
{
    public const string SectionName = "Auth";

    public AdminCredential Admin { get; set; } = new();
    public List<CanteenAdminCredential> CanteenAdmins { get; set; } = [];
}

public sealed class AdminCredential
{
    public int Id { get; set; } = 1;
    public string Name { get; set; } = "Platform Admin";
    public string Email { get; set; } = "admin@gmail.com";
    public string Password { get; set; } = "admin@1234";
}

public sealed class CanteenAdminCredential
{
    public int Id { get; set; }
    public int CanteenId { get; set; }
    public string CanteenName { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}
