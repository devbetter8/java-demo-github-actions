<%@ page language="java" contentType="text/html; charset=UTF-8"
pageEncoding="UTF-8"%> <%@ page import="com.devops.GreetingService" %> <%@ page
import="java.net.InetAddress" %> <% GreetingService svc = new GreetingService();
String appVersion = application.getInitParameter("app.version"); String appName
= application.getInitParameter("app.name"); String imageTag =
System.getenv("IMAGE_TAG") != null ? System.getenv("IMAGE_TAG") : "latest";
String buildNumber = System.getenv("BUILD_NUMBER") != null ?
System.getenv("BUILD_NUMBER") : "local"; String containerHost =
InetAddress.getLocalHost().getHostName(); %>
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><%= appName %> – Webapp Java</title>
    <style>
      *,
      *::before,
      *::after {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }
      body {
        font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
        background: #0d1117;
        color: #c9d1d9;
        min-height: 100vh;
        display: flex;
        flex-direction: column;
      }
      header {
        background: linear-gradient(135deg, #0a6e3f 0%, #1ab775 100%);
        padding: 2rem;
        text-align: center;
      }
      header h1 {
        font-size: 2.2rem;
        color: #fff;
        letter-spacing: 2px;
      }
      header p {
        color: #b7f5d8;
        margin-top: 0.4rem;
        font-size: 1rem;
      }
      main {
        flex: 1;
        max-width: 960px;
        margin: 2rem auto;
        padding: 0 1rem;
        width: 100%;
      }
      .greeting {
        background: #161b22;
        border: 1px solid #30363d;
        border-left: 4px solid #1ab775;
        border-radius: 8px;
        padding: 1.4rem 1.8rem;
        margin-bottom: 2rem;
        font-size: 1.1rem;
        color: #b7f5d8;
      }
      /* Boucle DevOps */
      .devops-loop {
        display: flex;
        justify-content: center;
        margin-bottom: 2rem;
        padding: 3rem 0;
      }
      .loop-stage {
        position: relative;
        display: flex;
        align-items: center;
      }
      .loop-ring {
        width: 200px;
        height: 200px;
        border-radius: 50%;
        border: 34px solid;
        position: relative;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .loop-dev {
        border-color: #1b3358;
        margin-right: -34px;
        z-index: 1;
      }
      .loop-ops {
        border-color: #1ab775;
        margin-left: -34px;
        z-index: 0;
      }
      .loop-center {
        font-size: 1.4rem;
        font-weight: 700;
        letter-spacing: 1px;
      }
      .loop-dev .loop-center {
        color: #1ab775;
      }
      .loop-ops .loop-center {
        color: #e6edf3;
      }
      .loop-label {
        position: absolute;
        z-index: 5;
        background: #21262d;
        border: 1px solid #30363d;
        color: #c9d1d9;
        font-size: 0.75rem;
        font-weight: 600;
        padding: 0.3rem 0.7rem;
        border-radius: 20px;
        white-space: nowrap;
      }
      .lbl-top {
        top: -16px;
        left: 50%;
        transform: translate(-50%, -50%);
      }
      .lbl-bottom {
        bottom: -16px;
        left: 50%;
        transform: translate(-50%, 50%);
      }
      .lbl-left {
        left: -16px;
        top: 50%;
        transform: translate(-50%, -50%);
      }
      .lbl-right {
        right: -16px;
        top: 50%;
        transform: translate(50%, -50%);
      }
      .lbl-cross-top {
        top: 14px;
        left: 50%;
        transform: translate(-50%, -50%);
        z-index: 6;
      }
      .lbl-cross-bottom {
        bottom: 14px;
        left: 50%;
        transform: translate(-50%, 50%);
        z-index: 6;
      }
      /* Info cards */
      .cards {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1rem;
        margin-bottom: 2rem;
      }
      .card {
        background: #161b22;
        border: 1px solid #30363d;
        border-radius: 8px;
        padding: 1.2rem;
      }
      .card h3 {
        font-size: 0.75rem;
        text-transform: uppercase;
        color: #8b949e;
        margin-bottom: 0.5rem;
      }
      .card p {
        font-size: 1rem;
        color: #e6edf3;
        font-weight: 600;
        word-break: break-all;
      }
      .card .badge {
        display: inline-block;
        background: #0a3d22;
        color: #b7f5d8;
        border-radius: 20px;
        padding: 0.2rem 0.8rem;
        font-size: 0.85rem;
      }
      footer {
        text-align: center;
        padding: 1.2rem;
        font-size: 0.8rem;
        color: #484f58;
        border-top: 1px solid #21262d;
      }
    </style>
  </head>
  <body>
    <header>
      <h1><%= appName %></h1>
    </header>

    <main>
      <div class="greeting"><%= svc.greet("M1 DevOps") %></div>

      <!-- Boucle DevOps -->
      <div class="devops-loop">
        <div class="loop-stage">
          <div class="loop-ring loop-dev">
            <span class="loop-label lbl-top">code</span>
            <span class="loop-label lbl-left">build</span>
            <span class="loop-label lbl-bottom">test</span>
            <span class="loop-center">Dev</span>
          </div>
          <div class="loop-ring loop-ops">
            <span class="loop-label lbl-top">deploy</span>
            <span class="loop-label lbl-right">operate</span>
            <span class="loop-label lbl-bottom">monitor</span>
            <span class="loop-center">Ops</span>
          </div>
          <span class="loop-label lbl-cross-top">plan</span>
          <span class="loop-label lbl-cross-bottom">release</span>
        </div>
      </div>

      <!-- Informations runtime -->
      <div class="cards">
        <div class="card">
          <h3>Application</h3>
          <p><span class="badge"><%= appVersion %></span></p>
        </div>
        <div class="card">
          <h3>Image Docker</h3>
          <p>ftutorials/webapp-java:<%= imageTag %></p>
        </div>
        <div class="card">
          <h3>Build Jenkins</h3>
          <p>#<%= buildNumber %></p>
        </div>
        <div class="card">
          <h3>Conteneur Docker</h3>
          <p><%= containerHost %></p>
        </div>
      </div>
    </main>

    <footer>
      D&eacute;ploy&eacute; automatiquement
    </footer>
  </body>
</html>
