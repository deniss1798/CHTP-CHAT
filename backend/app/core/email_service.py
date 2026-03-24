import os
import smtplib
from email.mime.text import MIMEText


def send_verification_code_email(to_email: str, code: str) -> None:
    smtp_host = os.getenv("SMTP_HOST")
    smtp_port = os.getenv("SMTP_PORT")
    smtp_user = os.getenv("SMTP_USER")
    smtp_password = os.getenv("SMTP_PASSWORD")
    smtp_from = os.getenv("SMTP_FROM")

    if not all([smtp_host, smtp_port, smtp_user, smtp_password, smtp_from]):
        raise RuntimeError("SMTP env vars are not fully configured")

    subject = "Код подтверждения ЧТП ЧАТ"
    body = (
        f"Ваш код подтверждения: {code}\n\n"
        f"Код действует 10 минут.\n"
        f"Если вы не запрашивали регистрацию, просто проигнорируйте это письмо."
    )

    msg = MIMEText(body, _charset="utf-8")
    msg["Subject"] = subject
    msg["From"] = smtp_from
    msg["To"] = to_email

    with smtplib.SMTP(smtp_host, int(smtp_port)) as server:
        server.starttls()
        server.login(smtp_user, smtp_password)
        server.sendmail(smtp_from, [to_email], msg.as_string())