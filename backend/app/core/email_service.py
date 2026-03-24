import smtplib
from email.mime.text import MIMEText

from app.core.config import get_settings

settings = get_settings()


def send_verification_code_email(to_email: str, code: str) -> None:
    subject = "ЧТП ЧАТ — код подтверждения"
    body = f"Ваш код подтверждения: {code}"

    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = settings.smtp_from
    msg["To"] = to_email

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as server:
        server.starttls()
        server.login(settings.smtp_user, settings.smtp_password)
        server.sendmail(settings.smtp_from, [to_email], msg.as_string())