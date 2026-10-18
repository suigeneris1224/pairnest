import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/models.dart';

class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {super.key, this.onTap, this.walletName});

  final Txn txn;
  final VoidCallback? onTap;

  /// "GCash" when it was paid from or received into a wallet.
  final String? walletName;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final style = categoryStyle(txn.category);
    final sign = txn.isMove
        ? '⇄ '
        : txn.isExpense
        ? '- '
        : txn.isTransfer
        ? '→ '
        : txn.isRelease
        ? '← '
        : '+ ';
    final amountColor = txn.isExpense || txn.isMove
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
            txn.isMove ? const PastelIcon(Icons.swap_horiz_rounded, tone: Pastel.sky, size: 44) : CategoryIcon(txn.category),
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
                    [
                      txn.isMove ? 'Moved between wallets' : style.label,
                      if (txn.userName.isNotEmpty) txn.userName,
                      if (walletName != null && !txn.isMove) walletName!,
                      if (txn.isSplit) 'Split',
                    ].join(' · '),
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
