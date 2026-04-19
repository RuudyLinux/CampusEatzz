namespace UniversityCanteen.Api.Configuration;

public sealed class FcmOptions
{
    public const string SectionName = "Fcm";

    public bool Enabled { get; set; } = false;
    public string ProjectId { get; set; } = string.Empty;
    public string ServiceAccountJsonPath { get; set; } = string.Empty;
    public string AndroidChannelId { get; set; } = "campuseatzz_updates";
}
