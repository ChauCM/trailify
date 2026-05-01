import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:trailify/trailify.dart';

@RoutePage()
class ProductDetailScreen extends StatelessWidget {
  final String id;

  const ProductDetailScreen({
    super.key,
    @PathParam('id') required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final product = _mockProducts[id] ?? _defaultProduct;

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: product.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(product.icon, size: 80, color: product.color),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Trailify.instance.userAction(
                      action: 'add_to_cart',
                      details: {
                        'productId': id,
                        'productName': product.name,
                        'price': product.price,
                      },
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Add to Cart'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () {
                  Trailify.instance.userAction(
                    action: 'toggle_favorite',
                    details: {'productId': id, 'isFavorite': true},
                  );
                },
                icon: const Icon(Icons.favorite_border_rounded),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Product {
  final String name;
  final String description;
  final double price;
  final IconData icon;
  final Color color;

  const _Product({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    required this.color,
  });
}

const _defaultProduct = _Product(
  name: 'Unknown Product',
  description: 'Product details not available.',
  price: 0.0,
  icon: Icons.help_outline,
  color: Colors.grey,
);

const _mockProducts = {
  '42': _Product(
    name: 'Wireless Headphones',
    description:
        'Premium noise-cancelling wireless headphones with 30-hour battery life. '
        'Features adaptive sound control, speak-to-chat, and multipoint connection.',
    price: 349.99,
    icon: Icons.headphones_rounded,
    color: Colors.deepPurple,
  ),
  '7': _Product(
    name: 'Smart Watch',
    description:
        'Advanced fitness tracker with heart rate monitoring, GPS, and sleep analysis. '
        'Water resistant to 50m with a 7-day battery life.',
    price: 299.99,
    icon: Icons.watch_rounded,
    color: Colors.teal,
  ),
  '15': _Product(
    name: 'Portable Speaker',
    description:
        'Compact Bluetooth speaker with 360-degree sound. '
        'IP67 waterproof rating and 12-hour playback time.',
    price: 129.99,
    icon: Icons.speaker_rounded,
    color: Colors.orange,
  ),
};
