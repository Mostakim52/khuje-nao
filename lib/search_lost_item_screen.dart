import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'chat_page.dart';
import 'localization.dart';

/// A screen for searching lost items by entering a query in a search bar.
///
/// The user can input a search query and view the list of lost items that match
/// the query. Each result includes an image of the lost item, and the option to
/// either start a chat with the person who reported the item or mark it as found.
///
/// The UI supports dynamic localization based on the user's language preference.
class SearchLostItemsScreen extends StatefulWidget {
  /// Creates a new instance of [SearchLostItemsScreen].
  const SearchLostItemsScreen({Key? key}) : super(key: key);

  @override
  SearchLostItemsScreenState createState() => SearchLostItemsScreenState();
}

class SearchLostItemsScreenState extends State<SearchLostItemsScreen> {
  /// Controller for the search query text field.
  final TextEditingController query_controller = TextEditingController();

  /// A list of search results containing information about the lost items.
  List<Map<String, dynamic>> search_results = [];

  /// A boolean that indicates whether the search is in progress.
  bool is_loading = false;

  /// An instance of [FlutterSecureStorage] to securely store user preferences.
  final FlutterSecureStorage STORAGE = const FlutterSecureStorage();

  /// The language code for localization (default is 'en').
  String language = 'en';

  @override
  void initState() {
    super.initState();
    loadLanguage();
  }

  /// Loads the user's preferred language from secure storage.
  ///
  /// If no language is stored, it defaults to `'en'` (English).
  Future<void> loadLanguage() async {
    String? stored_language = await STORAGE.read(key: 'language');
    setState(() {
      language = stored_language ?? 'en';
    });
  }

  /// Searches for lost items based on the entered query.
  ///
  /// If the query is empty, a snackbar is shown prompting the user to enter a query.
  /// Otherwise, the search results are fetched from the server using [ApiService].
  Future<void> searchItems() async {
    try {
      final query = query_controller.text;

      // If the search query is empty, show an error message
      if (query.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a search query!')),
        );
        return;
      }

      setState(() {
        is_loading = true;
      });

      // Fetch the search results from the backend
      final results = await ApiService().searchLostItems(query: query);

      setState(() {
        search_results = results.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Error searching items: $e');
    } finally {
      setState(() {
        is_loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalization.getString(language, 'search_lost'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Text field for entering search query
            TextField(
              controller: query_controller,
              decoration: InputDecoration(labelText: AppLocalization.getString(language, 'search_query')),
            ),
            const SizedBox(height: 20),

            // Search button
            ElevatedButton(
              onPressed: searchItems,
              child: Text(AppLocalization.getString(language, 'search')),
            ),
            const SizedBox(height: 20),

            // Display a loading indicator while the search is in progress
            is_loading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
              child: ListView.builder(
                itemCount: search_results.length,
                itemBuilder: (context, index) {
                  final item = search_results[index];
                  final reportedByEmail = item["reported_by"] ?? "";
                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display item image, or a placeholder if the image is missing
                        item["image"] != null && item["image"]!.isNotEmpty
                            ? Image.network(
                          item["image"]!,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            size: 50,
                          ),
                        )
                            : Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item["description"] ?? "No description provided",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Location: ${item["location"] ?? "Unknown"}",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700]),
                              ),
                              // FutureBuilder to fetch the current user email and decide whether to show "Chat" or "Mark as Found" button
                              FutureBuilder<String?>(
                                future: STORAGE.read(key: "email"), // Fetch current user email
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const SizedBox(); // Show empty widget while loading
                                  }

                                  final currentUserEmail = snapshot.data;
                                  final reportedByEmail = item["reported_by"] ?? "";

                                  // Only show the button if the current user's email is not the same as the reported_by email
                                  if (currentUserEmail != null && currentUserEmail != reportedByEmail) {
                                    return ElevatedButton(
                                      onPressed: () async {
                                        // Save the receiver email to storage
                                        await STORAGE.write(key: "receiver_email", value: reportedByEmail);

                                        // Navigate to the ChatPage
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => ChatPage()),
                                        );
                                      },
                                      child: Text(AppLocalization.getString(language, 'chat')),
                                    );
                                  } else {
                                    return ElevatedButton(
                                      onPressed: () async {
                                        final itemId = item["_id"]; // Mark the item as found
                                        await ApiService().markItemAsFound(itemId);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Item marked as found')),
                                        );
                                      },
                                      child: const Text("Mark as Found"),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
