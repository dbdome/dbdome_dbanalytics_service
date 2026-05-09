import pyodbc
def get_installed_driver_by_priority():
    try:
        # Define driver priority
        priority = [
            "ODBC Driver 18 for SQL Server",
            "ODBC Driver 17 for SQL Server",
            "SQL Server"
        ]

        # Get installed drivers
        installed_drivers = pyodbc.drivers()
        if not installed_drivers:
            raise RuntimeError("No ODBC drivers installed!")

        # Select the first available driver by priority
        selected_driver = next((d for d in priority if d in installed_drivers), None)
        if selected_driver is None:
            raise RuntimeError("No suitable ODBC driver found from the priority list!")

        print("Selected driver:", selected_driver)
        return selected_driver

    except RuntimeError as e:
        print(f"[ERROR] {e}")
        return None
    except Exception as e:
        print(f"[UNEXPECTED ERROR] {e}")
        return None

