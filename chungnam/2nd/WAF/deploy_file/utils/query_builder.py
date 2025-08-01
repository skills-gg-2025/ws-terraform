def obscure_query(mode, **kwargs):
    if mode == "login":
        name = kwargs["name"]
        secret = kwargs["secret"]
        parts = ["SELECT", "*", "FROM", "secret_users", "WHERE"]
        parts.append(f"name='{name}'")
        parts.append("AND")
        parts.append(f"secret='{secret}'")
        return " ".join(parts)

    elif mode == "lookup":
        user_id = kwargs["id"]
        return f"""SELECT id, name, secret FROM secret_users WHERE id = {user_id}"""

    elif mode == "inspect":
        table = kwargs["table"]
        return f"""SELECT * FROM {table}"""

    return "SELECT 1"
