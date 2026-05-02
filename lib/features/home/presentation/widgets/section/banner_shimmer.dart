import 'package:flutter/material.dart';
import 'package:lilia_app/features/home/presentation/widgets/section/shimmer_banner_placeholder.dart';

Widget buildBannerShimmer() {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerBannerPlaceholder(),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            width: index == 0 ? 20 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.grey[300],
            ),
          );
        }),
      ),
    ],
  );
}
