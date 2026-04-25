using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using admin_files.Models;

namespace admin_files.Controllers;

public class HomeController : Controller
{
    private readonly IConfiguration _configuration;

    public HomeController(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    public IActionResult Index()
    {
        return View();
    }

    public IActionResult Privacy()
    {
        return View();
    }
    public IActionResult AdminAllOrders()
    {
        return View();
    }
    public IActionResult AdminContactMessages()
    {
        return View();
    }
    public IActionResult AdminDashboard()
    {
        return View();
    }
    public IActionResult AdminLogin()
    {
        var apiBaseUrl = _configuration["Frontend:ApiBaseUrl"] ?? "https://campuseatzz.onrender.com";
        ViewBag.ApiBaseUrl = apiBaseUrl;
        return View();
    }
    public IActionResult AdminManageCanteenAdmins()
    {
        return View();
    }
    public IActionResult AdminManageCanteens()
    {
        return View();
    }
    public IActionResult AdminManageUsers()
    {
        return View();
    }
    public IActionResult AdminOrderInvoice()
    {
        return View();
    }
    public IActionResult AdminReports()
    {
        return View();
    }
    public IActionResult AdminReviews()
    {
        return View();
    }
    public IActionResult AdminSettings()
    {
        return View();
    }
    public IActionResult AdminWallets()
    {
        return View();
    }
    public IActionResult AdminWalletTransactions()
    {
        return View();
    }
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
