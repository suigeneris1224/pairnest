import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/categories.dart';
import '../../data/models.dart';

class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {super.key, this.onTap});

  final Txn txn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final style = categoryStyle(txn.category);
    final sign = txn.isExpense
        ? '- '
        : txn.isTransfer
        ? '→ '
        : txn.isRelease
        ? '← '
        : '+ ';
    final amountColor = txn.isExpense
        ? p.text
        : txn.isTransfer || txn.isRelease
        ? savingsCategory.color
        : incomeCategory.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CategoryIcon(txn.category),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [style.label, if (txn.userName.isNotEmpty) txn.userName, if (txn.isSplit) 'Split'].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${peso(txn.amount)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: amountColor),
                ),
                const SizedBox(height: 2),
                Text(shortDate(txn.occurredOn), style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
