FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore only the API project first for better layer caching.
COPY backend/UniversityCanteen.Api/UniversityCanteen.Api.csproj backend/UniversityCanteen.Api/
RUN dotnet restore backend/UniversityCanteen.Api/UniversityCanteen.Api.csproj

# Copy API source and publish.
COPY backend/UniversityCanteen.Api/. backend/UniversityCanteen.Api/
RUN dotnet publish backend/UniversityCanteen.Api/UniversityCanteen.Api.csproj -c Release -o /app/out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .

# Render sets PORT at runtime; Program.cs binds to 0.0.0.0:{PORT}.
ENV ASPNETCORE_ENVIRONMENT=Production
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "UniversityCanteen.Api.dll"]