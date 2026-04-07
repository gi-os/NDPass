const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

/**
 * Expo config plugin that copies the SwiftUI widget into the iOS build
 * and sets up App Group for shared data between app and widget.
 */
function withNextShowingWidget(config) {
  // Copy widget Swift files into ios/ during prebuild
  config = withDangerousMod(config, [
    'ios',
    async (config) => {
      const projectRoot = config.modRequest.projectRoot;
      const widgetSrc = path.join(projectRoot, 'widgets', 'NextShowingWidget');
      const iosDir = path.join(projectRoot, 'ios', 'NextShowingWidget');

      // Create widget target directory
      if (!fs.existsSync(iosDir)) {
        fs.mkdirSync(iosDir, { recursive: true });
      }

      // Copy all Swift files
      const files = fs.readdirSync(widgetSrc);
      for (const file of files) {
        fs.copyFileSync(
          path.join(widgetSrc, file),
          path.join(iosDir, file)
        );
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withNextShowingWidget;
