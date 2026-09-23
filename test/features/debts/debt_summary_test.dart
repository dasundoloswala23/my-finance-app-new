import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/balance_math.dart';
import 'package:myfinance/features/debts/domain/debt.dart';
import 'package:myfinance/features/debts/providers.dart';

Debt _debt({
  required String id,
  required DebtDirection direction,
  required int principalMinor,
  int settledMinor = 0,
  DateTime? dueDate,
  DateTime? date,
}) {
  return Debt(
    id: id,
    personName: id,
    direction: direction,
    principalMinor: principalMinor,
    settledMinor: settledMinor,
    accountId: 'hand',
    date: date ?? DateTime(2026, 1, 1),
    dueDate: dueDate,
  );
}

void main() {
  group('Debt', () {
    test('outstanding is principal less settled', () {
      final debt = _debt(
        id: 'a',
        direction: DebtDirection.given,
        principalMinor: 500000,
        settledMinor: 200000,
      );
      expect(debt.outstandingMinor, 300000);
      expect(debt.isSettled, isFalse);
      expect(debt.isPartlySettled, isTrue);
    });

    test('is settled once nothing is outstanding', () {
      final debt = _debt(
        id: 'a',
        direction: DebtDirection.given,
        principalMinor: 500000,
        settledMinor: 500000,
      );
      expect(debt.outstandingMinor, 0);
      expect(debt.isSettled, isTrue);
      expect(debt.isPartlySettled, isFalse);
      expect(debt.progress, 1.0);
    });

    test('progress reports the fraction repaid', () {
      final debt = _debt(
        id: 'a',
        direction: DebtDirection.given,
        principalMinor: 400000,
        settledMinor: 100000,
      );
      expect(debt.progress, 0.25);
    });

    test('a debt is overdue only while it is still owed', () {
      final now = DateTime(2026, 6, 15);
      final open = _debt(
        id: 'a',
        direction: DebtDirection.given,
        principalMinor: 1000,
        dueDate: DateTime(2026, 6, 1),
      );
      final paid = _debt(
        id: 'b',
        direction: DebtDirection.given,
        principalMinor: 1000,
        settledMinor: 1000,
        dueDate: DateTime(2026, 6, 1),
      );
      final future = _debt(
        id: 'c',
        direction: DebtDirection.given,
        principalMinor: 1000,
        dueDate: DateTime(2026, 7, 1),
      );
      final noDueDate = _debt(
        id: 'd',
        direction: DebtDirection.given,
        principalMinor: 1000,
      );

      expect(open.isOverdue(now), isTrue);
      expect(paid.isOverdue(now), isFalse);
      expect(future.isOverdue(now), isFalse);
      expect(noDueDate.isOverdue(now), isFalse);
    });
  });

  group('receivableOf / payableOf', () {
    final debts = [
      _debt(id: 'lent-open', direction: DebtDirection.given, principalMinor: 500000),
      _debt(
        id: 'lent-part',
        direction: DebtDirection.given,
        principalMinor: 400000,
        settledMinor: 150000,
      ),
      _debt(
        id: 'lent-done',
        direction: DebtDirection.given,
        principalMinor: 300000,
        settledMinor: 300000,
      ),
      _debt(id: 'owed-open', direction: DebtDirection.taken, principalMinor: 200000),
      _debt(
        id: 'owed-done',
        direction: DebtDirection.taken,
        principalMinor: 100000,
        settledMinor: 100000,
      ),
    ];

    test('receivable counts only outstanding lent-out money', () {
      // 500000 + (400000 - 150000), settled debt excluded.
      expect(receivableOf(debts), 750000);
    });

    test('payable counts only outstanding borrowed money', () {
      expect(payableOf(debts), 200000);
    });

    test('both are zero with no debts', () {
      expect(receivableOf(const []), 0);
      expect(payableOf(const []), 0);
    });

    test('a fully settled list contributes nothing', () {
      final allSettled = [
        _debt(
          id: 'x',
          direction: DebtDirection.given,
          principalMinor: 1000,
          settledMinor: 1000,
        ),
        _debt(
          id: 'y',
          direction: DebtDirection.taken,
          principalMinor: 2000,
          settledMinor: 2000,
        ),
      ];
      expect(receivableOf(allSettled), 0);
      expect(payableOf(allSettled), 0);
    });
  });

  group('openDebtsOf', () {
    test('returns only open debts of the requested direction', () {
      final debts = [
        _debt(id: 'lent', direction: DebtDirection.given, principalMinor: 100),
        _debt(id: 'owed', direction: DebtDirection.taken, principalMinor: 100),
        _debt(
          id: 'lent-done',
          direction: DebtDirection.given,
          principalMinor: 100,
          settledMinor: 100,
        ),
      ];
      expect(
        openDebtsOf(debts, DebtDirection.given).map((d) => d.id),
        ['lent'],
      );
      expect(
        openDebtsOf(debts, DebtDirection.taken).map((d) => d.id),
        ['owed'],
      );
    });

    test('sorts by due date first, and dated debts above open-ended ones', () {
      final debts = [
        _debt(
          id: 'no-due',
          direction: DebtDirection.given,
          principalMinor: 100,
          date: DateTime(2026, 5, 1),
        ),
        _debt(
          id: 'due-late',
          direction: DebtDirection.given,
          principalMinor: 100,
          dueDate: DateTime(2026, 9, 1),
        ),
        _debt(
          id: 'due-soon',
          direction: DebtDirection.given,
          principalMinor: 100,
          dueDate: DateTime(2026, 7, 1),
        ),
      ];
      expect(
        openDebtsOf(debts, DebtDirection.given).map((d) => d.id),
        ['due-soon', 'due-late', 'no-due'],
      );
    });
  });

  group('settledDebtsOf', () {
    test('returns only closed debts, newest first', () {
      final debts = [
        _debt(id: 'open', direction: DebtDirection.given, principalMinor: 100),
        _debt(
          id: 'older',
          direction: DebtDirection.given,
          principalMinor: 100,
          settledMinor: 100,
          date: DateTime(2026, 1, 1),
        ),
        _debt(
          id: 'newer',
          direction: DebtDirection.taken,
          principalMinor: 100,
          settledMinor: 100,
          date: DateTime(2026, 3, 1),
        ),
      ];
      expect(settledDebtsOf(debts).map((d) => d.id), ['newer', 'older']);
    });
  });
}
