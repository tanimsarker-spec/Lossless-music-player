import 'package:flutter/material.dart';
import 'theme.dart';

/// Top-of-screen brand mark: LOSSLESS wordmark with a small "TanimSarker"
/// signature beneath it.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LOSSLESS by TanimSarker',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LOSSLESS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 6,
              color: LColors.silver,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'TanimSarker',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2.4,
              color: LColors.silverDim,
            ),
          ),
        ],
      ),
    );
  }
}
