import { extendTheme } from "@chakra-ui/react";
import { lightThemeColors } from "./colors";
import { cardTheme } from "./card";
import { ButtonStyle } from "./button";

const themeConfig = {
  components: {
    Card: cardTheme,
    Button: ButtonStyle,
  },

  // 2. Add your color mode config
  initialColorMode: "system",
  useSystemColorMode: true,

  semanticTokens: {
    colors: {
      "chakra-body-text": {
        _light: "#1E1E1E",
      },
      "chakra-body-bg": {
        _light: "#F7F7F7",
      },
    },
  },
  colors: {
    //dynamic primary coor based on the light/dark

    green: {
      "50": "#f3f9f3",
      "100": "#cfe6d0",
      "200": "#a4d1a6",
      "300": "#6fb672",
      "400": "#51a654",
      "500": "#259029",
      "600": "#007b05",
      "700": "#006304",
      "800": "#005403",
      "900": "#003d02",
    },
  },
};

export const lightTheme = extendTheme({
  ...themeConfig,
  colors: lightThemeColors,
});
