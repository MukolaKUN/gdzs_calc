import 'package:flutter/material.dart';

class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              const SizedBox(width: 20),

              Icon(
                icon,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(width: 20),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Icon(Icons.chevron_right),

              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}
