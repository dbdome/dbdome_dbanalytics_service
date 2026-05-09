import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import os

def send_mail_with_attachment(
        smtp_server,
        smtp_port,
        smtp_user,
        smtp_pass,
        sender,
        recipients,
        subject,
        body,
        attachment_path
):
    # Create the base message
    msg = MIMEMultipart()
    msg["From"] = sender
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = subject

    # Add body
    msg.attach(MIMEText(body, "plain"))

    # Attach file
    if attachment_path and os.path.isfile(attachment_path):
        filename = os.path.basename(attachment_path)
        with open(attachment_path, "rb") as attachment:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(attachment.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename={filename}",
            )
            msg.attach(part)
    else:
        print("Attachment not found:", attachment_path)
        return False

    # Send via SMTP
    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()  # secure connection
            server.login(smtp_user, smtp_pass)
            server.sendmail(sender, recipients, msg.as_string())
            print("Email sent successfully!")
            return True
    except Exception as e:
        print("Error sending email:", e)
        return False


# -------------------------------
# Example usage
# -------------------------------
if __name__ == "__main__":

    SMTP_SERVER = "smtp.gmail.com"
    SMTP_PORT = 587
    SMTP_USER = "ydan.012.net.il@gmail.com"
    SMTP_PASS = "Yd2243796Anz!!"    # Gmail App Password

    send_mail_with_attachment(
        smtp_server=SMTP_SERVER,
        smtp_port=SMTP_PORT,
        smtp_user=SMTP_USER,
        smtp_pass=SMTP_PASS,
        sender="yoram@dbdome.com",
        recipients=["yoram@dbdome.com"],
        subject="install",
        body="Attached is the required report.",
        attachment_path="C:\\INSTALLS\\dbdome_install.z01"
    )