<%@ Page Language="C#" AutoEventWireup="true" Async="true" %>
<%@ Import Namespace="System.Net.Http" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Threading.Tasks" %>
<%@ Import Namespace="System.Web.Configuration" %>

<script runat="server"> 
    protected void Page_Load(object sender, EventArgs e)
    {
        // Force only AJAX POST requests, drop others
        if (Request.HttpMethod == "POST")
        {
            PageAsyncTask task = new PageAsyncTask(ProcessFormSubmissionAsync);
            RegisterAsyncTask(task);
        }
        else
        {
            SendJsonResponse(false, "Invalid request method.");
            return;
        }
    }

    private async Task ProcessFormSubmissionAsync()
    {
        // Map Variables 
        string name = Request.Form["name"];
        string email = Request.Form["email"];
        string message = Request.Form["message"];
        string turnstileResponse = Request.Form["cf-turnstile-response"];

        // Secure Vars - use env/conf vars only, no hardcode.
        string turnstileSecret = "";
        string tenantId = "";
        string clientId = "";
        string clientSecret = "";

    #if DEBUG
    // Debug Logic stripped in release builds.

        turnstileSecret = Environment.GetEnvironmentVariable("TurnstileSecret", EnvironmentVariableTarget.Process);
        tenantId = Environment.GetEnvironmentVariable("tenantId", EnvironmentVariableTarget.Process);
        clientId = Environment.GetEnvironmentVariable("clientId", EnvironmentVariableTarget.Process);
        clientSecret = Environment.GetEnvironmentVariable("clientSecret", EnvironmentVariableTarget.Process);
    #else
        turnstileSecret = WebConfigurationManager.AppSettings["TurnstileSecret"];
        tenantId = WebConfigurationManager.AppSettings["tenantId"];
        clientId = WebConfigurationManager.AppSettings["clientId"];
        clientSecret = WebConfigurationManager.AppSettings["clientSecret"];

    #endif

        // Constrain Routing
        string sendingMailbox = "noreply@plagued.gg";
        string destinationMailbox = "info@plagued.gg";

        if (string.IsNullOrEmpty(turnstileResponse) || string.IsNullOrEmpty(email) || string.IsNullOrEmpty(message))
        {
            SendJsonResponse(false, "Missing required parameters.");
            return;
        }

        // Verify Captcha
        bool isHuman = await ValidateTurnstile(turnstileResponse, turnstileSecret);
        if (!isHuman)
        {
            SendJsonResponse(false, "Security verification failed. Please refresh and try again.");
            return;
        }

        // GraphAPI Integration - Get Token 
        string accessToken = await GetGraphAccessToken(tenantId, clientId, clientSecret);
        if (string.IsNullOrEmpty(accessToken))
        {
            SendJsonResponse(false, "Internal authentication setup failure in Graph API.");
            return;
        }

        // Build payload and attempt delivery. 
        bool emailSent = await SendGraphEmail(accessToken, sendingMailbox, destinationMailbox, name, email, message);
        if (emailSent)
        {
            SendJsonResponse(true, "Success");
        }
        else
        {
            SendJsonResponse(false, "Verification passed, but something went wrong with the graph API delivery.");
        }

    }



    private async Task<bool> ValidateTurnstile(string responseToken, string secretKey)
    {
        string siteverifyUrl = "https://challenges.cloudflare.com/turnstile/v0/siteverify";
        try
        {
            using (HttpClient client = new HttpClient())
            {
                var values = new Dictionary<string, string> { { "secret", secretKey }, { "response", responseToken } };
                var content = new FormUrlEncodedContent(values);
                var response = await client.PostAsync(siteverifyUrl, content);

                if (response.IsSuccessStatusCode)
                {
                    string jsonString = await response.Content.ReadAsStringAsync();
                    var serializer = new JavaScriptSerializer();
                    var jsonData = serializer.Deserialize<Dictionary<string, object>>(jsonString);

                    if (jsonData != null && jsonData.ContainsKey("success"))
                    {
                        return (bool)jsonData["success"];
                    }
                }
            }
        } catch { }
        return false;
    }

    private async Task<string> GetGraphAccessToken(string tenantId, string clientId, string clientSecret)
    {
        try
        {
            // Bind TLS 1.2+ only. Graph rejects lower. 
            System.Net.ServicePointManager.SecurityProtocol |= System.Net.SecurityProtocolType.Tls12;

            using (HttpClient client = new HttpClient())
            {
                var values = new Dictionary<string, string>
    {
        {"grant_type", "client_credentials" },
        { "client_id", clientId },
        { "client_secret", clientSecret },
        { "scope", "https://graph.microsoft.com/.default" }
    };

                var content = new FormUrlEncodedContent(values);
                string tokenUrl = "https://login.microsoftonline.com/" + tenantId + "/oauth2/v2.0/token";

                var response = await client.PostAsync(tokenUrl, content);

                if (response.IsSuccessStatusCode)
                {
                    string jsonString = await response.Content.ReadAsStringAsync();
                    var serializer = new JavaScriptSerializer();
                    var jsonData = serializer.Deserialize<Dictionary<string, object>>(jsonString);

                    if (jsonData != null && jsonData.ContainsKey("access_token"))
                    {
                        return jsonData["access_token"].ToString();
                    }
                }
            }
        } catch { }
        return null;
    }

    private async Task<bool> SendGraphEmail(string token, string sender, string recipient, string fromName, string fromEmail, string msgBody)
    {
        try
        {
            using (HttpClient client = new HttpClient())
            {
                client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

                string emailSubject = string.Format("New Contact Form Entry from {0}", fromName);
                string emailContent = string.Format(
                    "<h3>New Message from Web Contact Form</h3>" +
                    "<p><strong>Name:</strong> {0}</p>" +
                    "<p><strong>Email:</strong> {1}</p>" +
                    "<p><strong>Message:</strong></p>" +
                    "<p style='background:#1a1a1a; color:#ffffff; padding:15px; border-left:4px solid #007acc; white-space:pre-wrap;'>{2}</p>",
                    HttpUtility.HtmlEncode(fromName),
                    HttpUtility.HtmlEncode(fromEmail),
                    HttpUtility.HtmlEncode(msgBody)
                );

                var mailPayload = new
                {
                    message = new
                    {
                        subject = emailSubject,
                        body = new
                        {
                            contentType = "HTML",
                            content = emailContent
                        },
                        toRecipients = new[] { new { emailAddress = new { address = recipient } } }
                    }
                };

                var serializer = new JavaScriptSerializer();
                string jsonPayload = serializer.Serialize(mailPayload);
                var content = new StringContent(jsonPayload, System.Text.Encoding.UTF8, "application/json");

                string graphURL = "https://graph.microsoft.com/v1.0/users/" + sender + "/sendMail";
                var response = await client.PostAsync(graphURL, content);

                return response.IsSuccessStatusCode;
            }
        } catch { }
        return false;

    }

    private void SendJsonResponse(bool success, string message)
    {
        Response.Clear();
        Response.ContentType = "application/json";
        var result = new { success = success, message = message };
        Response.Write(new JavaScriptSerializer().Serialize(result));
        Response.End();
    }
</script>