import requests
from utils.log4dbexpert import db_write_log
import os
from requests_ntlm import HttpNtlmAuth



def ssrs_download_alert_report(report_url,report_user , report_password , filename, output_dir="."):
    """
    Downloads an SSRS report and returns the file path if successful.
    """
    # Authentication (Windows NTLM or Basic)
    auth = HttpNtlmAuth(report_user, report_password)
    

    # Ensure output directory exists
    #output_dir = os.getcwd() + os.sep + "\report_to_send\\"
    os.makedirs(output_dir, exist_ok=True)
    filename = "report_to_send.pdf"
    file_path = os.path.join(output_dir, filename)
    
    try:
        response = requests.get(report_url, auth=auth)
        if response.status_code == 200:
            with open(file_path, "wb") as f:
                f.write(response.content)

            db_write_log(
                f"Report downloaded successfully: {report_url}",
                "ssrs_download",
                "ssrs_download_alert_report",
                "mail_server"
            )
            return file_path  # ✅ Return file path here

        else:
            db_write_log(
                f"Failed to download report: {response.status_code}",
                "ssrs_download",
                "ssrs_download_alert_report",
                 "mail_server"
            )
            return None

    except Exception as e:
        db_write_log(
            f"Error downloading report: {e}",
            "ssrs_download",
            "ssrs_download_alert_report",
             "mail_server"
        )
        return None

def ssrs_download_alert_report_with_params(report_url,report_user , report_password , filename, start_time , end_time ,output_dir="." ):
    """
    Downloads an SSRS report and returns the file path if successful.
    """
    # Authentication (Windows NTLM or Basic)
    auth = HttpNtlmAuth(report_user, report_password)
    
    full_report_url  = (f"{report_url}&rs:start_time={start_time}&rs:end_time={end_time}&rs:Format=PDF")
    # Ensure output directory exists
    #output_dir = os.getcwd() + os.sep + "\report_to_send\\"
    os.makedirs(output_dir, exist_ok=True)
    filename = "report_to_send.pdf"
    file_path = os.path.join(output_dir, filename)

    try:
        response = requests.get(full_report_url, auth=auth)
        if response.status_code == 200:
            with open(file_path, "wb") as f:
                f.write(response.content)

            db_write_log(
                f"Report downloaded successfully: {report_url}&rs:start_time={start_time}&rs:end_time={end_time}&rs:Format=PDF",
                "ssrs_download",
                "ssrs_download_alert_report_with_params",
                "mail_server"
            )
            return file_path  # ✅ Return file path here

        else:
            db_write_log(
                f"Failed to download report: {response.status_code}",
                "ssrs_download",
                "ssrs_download_alert_report_with_params"
                 "mail_server"
            )
            return None

    except Exception as e:
        db_write_log(
            f"Error downloading report: {e}",
            "ssrs_download",
            "ssrs_download_alert_report_with_params"
             "mail_server"
        )
        return None