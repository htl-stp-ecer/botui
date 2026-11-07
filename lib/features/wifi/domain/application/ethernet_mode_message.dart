/// The badge text after switching to Ethernet Mode, by how it was set up.
String ethernetModeMessage(String? role) => switch (role) {
      'client' => 'Successfully connected via Ethernet',
      'host' => 'No LAN detected after 10s, hosting one',
      _ => 'Switched to Ethernet Mode',
    };
