import { Box, Container, HStack, Image, Button } from "@chakra-ui/react";
import { Link } from "react-router-dom";
import { ConnectWalletButton } from "./ConnectWalletButton";

export const Navbar = () => {
  return (
    <Box
      px={0}
      position={"sticky"}
      top={0}
      zIndex={10}
      py={4}
      h={"auto"}
      w={"full"}
      bg={"#f7f7f7"}
    >
      <Container
        w="full"
        display="flex"
        flexDirection="row"
        justifyContent="space-between"
        alignItems={"center"}
        maxW={"container.xl"}
      >
        {/* Logo and Navigation Links */}
        <HStack flex={1} justifyContent={"start"}>
          <Link to="/">
            <Image src="/vebetterdao-logo.svg" alt="Logo" />
          </Link>
          <Link to="/meal-planning">
            <Button variant="ghost" colorScheme="teal">
              Meal Planning
            </Button>
          </Link>
          <Link to="/instructions">
            <Button variant="ghost" colorScheme="teal">
              Instructions
            </Button>
          </Link>
          <Link to="/upload">
            <Button variant="ghost" colorScheme="teal">
              Upload
            </Button>
          </Link>
        </HStack>

        {/* Wallet Button */}
        <HStack flex={1} spacing={4} justifyContent={"end"}>
          <ConnectWalletButton />
        </HStack>
      </Container>
    </Box>
  );
};
