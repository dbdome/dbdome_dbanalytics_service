from zeep import Client
from zeep.transports import Transport
import requests
from requests_ntlm import HttpNtlmAuth

def add_ssrs_user(
    ssrs_server_url,
    domain_user,
    ssrs_admin_user,
    ssrs_admin_password,
    role_name="Browser",
    folder_path="/"
):
    """
    Adds a user to SSRS with the specified role.

    :param ssrs_server_url: Base URL of SSRS ReportServer (e.g., http://win-c2qji2p85or)
    :param domain_user: User to add (e.g., DOMAIN\\targetuser)
    :param ssrs_admin_user: Admin user (e.g., DOMAIN\\admin)
    :param ssrs_admin_password: Admin password
    :param role_name: SSRS role to assign (default: Browser)
    :param folder_path: Report folder path to apply permissions on (default: root '/')
    """

    wsdl_url = f"{ssrs_server_url}/ReportService2010.asmx?wsdl"

    # Set up NTLM authentication
    session = requests.Session()
    session.auth = HttpNtlmAuth(ssrs_admin_user, ssrs_admin_password)
    transport = Transport(session=session)

    # Initialize client
    client = Client(wsdl=wsdl_url, transport=transport)

    # Fetch current policies
    policies = client.service.GetPolicies(folder_path, True)

    # Check if user already exists
    user_exists = any(p.GroupUserName.lower() == domain_user.lower() for p in policies)

    if user_exists:
        print(f"User {domain_user} already has permissions on {folder_path}.")
        return

    # Define new policy
    role = client.get_type('ns0:Role')()
    role.Name = role_name

    policy = client.get_type('ns0:Policy')()
    policy.GroupUserName = domain_user
    policy.Roles = [role]

    # Append new policy
    updated_policies = list(policies) + [policy]

    # Apply updated policies
    client.service.SetPolicies(folder_path, updated_policies)

    print(f"✅ User {domain_user} was added with role '{role_name}' to {folder_path}.")