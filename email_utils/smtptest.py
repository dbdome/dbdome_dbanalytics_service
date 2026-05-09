from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import aiosmtplib
import base64
import uvicorn

app = FastAPI()

# -----------------------------
# GMAIL SMTP CONFIGURATION
# -----------------------------
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USER = "ydan.012.net.il@gmail.com"       # <-- your Gmail
SMTP_PASS = "Yd22437968Anz!!"         # <-- 16-char App Password


# -----------------------------
# Request Model
# -----------------------------
class EmailRequest(BaseModel):
    to_email: str
    subject: str
    body: str
    attachment_name: str | None = None
    attachment_base64: str | None = None


# -----------------------------
# Send Email API
# -----------------------------
@app.post("/send_email")
async def send_email(req: EmailRequest):
    try:
        # Create email
        msg = MIMEMultipart()
        msg["From"] = SMTP_USER
        msg["To"] = req.to_email
        msg["Subject"] = req.subject

        msg.attach(MIMEText(req.body, "html"))

        # Optional attachment
        if req.attachment_name and req.attachment_base64:
            file_bytes = base64.b64decode(req.attachment_base64)
            part = MIMEApplication(file_bytes)
            part.add_header("Content-Disposition",
                            f'attachment; filename="{req.attachment_name}"')
            msg.attach(part)

        # Send email using Gmail SMTP
        await aiosmtplib.send(
            message=msg,
            hostname=SMTP_SERVER,
            port=SMTP_PORT,
            start_tls=True,
            username=SMTP_USER,
            password=SMTP_PASS,
        )

        return {"status": "ok", "message": "Email sent successfully"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


uvicorn.run(app, host="0.0.0.0", port=8081)    