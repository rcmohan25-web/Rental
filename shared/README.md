# shared/

Data shared by Dart tests and SQL tests so the two implementations cannot drift apart.

- `fixtures/money_cases.json`: Smaran writes the cases (days, fee, deposit, commission, late fee). Dart `money.dart` and the SQL functions must both match every case.
- `fixtures/status_transitions.json`: Srijan writes allowed and forbidden status transitions.
