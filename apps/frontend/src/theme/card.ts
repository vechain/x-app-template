import {
  StyleFunctionProps,
  createMultiStyleConfigHelpers,
} from "@chakra-ui/react";
import { cardAnatomy } from "@chakra-ui/anatomy";

const { definePartsStyle, defineMultiStyleConfig } =
  createMultiStyleConfigHelpers(cardAnatomy.keys);

// define custom styles for funky variant
const variants = {
  base: (props: StyleFunctionProps) =>
    definePartsStyle({
      container: {
        bg: props.colorMode === "dark" ? "#1A1A1A" : "#FFF",
        borderWidth: "1px",
        borderColor: props.colorMode === "dark" ? "#2D2D2F" : "transparent",
      },
    }),
  filled: (props: StyleFunctionProps) =>
    definePartsStyle({
      container: {
        bg: props.colorMode === "dark" ? "#2D2D2F" : "#FAFAFA",
      },
    }),
  baseWithBorder: (props: StyleFunctionProps) =>
    definePartsStyle({
      container: {
        bg: props.colorMode === "dark" ? "#1A1A1A" : "#FFF",
        borderWidth: "1px",
        borderColor: props.colorMode === "dark" ? "#2D2D2F" : "gray.100",
      },
    }),
  secondaryBoxShadow: (props: StyleFunctionProps) =>
    definePartsStyle({
      container: {
        boxShadow: "inset 0px 0px 100px 5px rgba(177, 241, 108, 1)",
        bg: props.colorMode === "dark" ? "#1A1A1A" : "#FFF",
        borderWidth: "1px",
        borderColor: props.colorMode === "dark" ? "#2D2D2F" : "gray.100",
      },
    }),
};

// export variants in the component theme
export const cardTheme = defineMultiStyleConfig({
  variants,
  defaultProps: {
    variant: "base", // default is solid
  },
});
