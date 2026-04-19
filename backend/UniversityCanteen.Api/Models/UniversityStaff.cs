namespace UniversityCanteen.Api.Models;

public sealed class UniversityStaff
{
    public string UniversityId { get; init; } = string.Empty;
    public string Department { get; init; } = string.Empty;
    public DateTime DateOfBirth { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
