namespace UniversityCanteen.Api.Models;

public sealed class Student
{
    public string UniversityId { get; init; } = string.Empty;
    public string Course { get; init; } = string.Empty;
    public int Semester { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
