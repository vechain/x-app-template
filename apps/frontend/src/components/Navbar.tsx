import { Box, Container, HStack, Image, Button } from "@chakra-ui/react";
import { Link } from "react-router-dom";
import { ConnectWalletButton } from "./ConnectWalletButton";

export const Navbar = ({ isAuthenticated, onLogout }: { isAuthenticated: boolean, onLogout: () => void }) => {
  return (
    <Box
      px={0}
      position={"sticky"}
      top={0}
      zIndex={10}
      py={2}
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
            <Button p="30px 20px"
              ms="40px"
              me="10px"
              bg= 'black'
              color="white"
              sx={{ _hover: {bg:"black",}}}
              >B3TRBites</Button>
              {/* <Image src="apps/frontend/public/B3TRBites.png"></Image> */}
          </Link>
          <Link to="/meal-planning">
            <Button
              variant="ghost"
              p="30px 20px"
              ms="40px"
              me="10px"
              sx={{
                color: 'black', // Default text color
                _hover: {
                  bg: 'rgba(0, 128, 0, 0.2)',  // Background color on hover
                },
              }}
            >
              Meal Planning
            </Button>
          </Link>
          <Link to="/inventory">
            <Button variant="ghost"
              p="30px 20px"
              ms="40px"
              me="10px"
              sx={{
                color: 'black', // Default text color
                _hover: {
                  bg: 'rgba(0, 128, 0, 0.2)',  // Background color on hover
                },
              }}>
              Inventory
            </Button>
          </Link>
          <Link to="/instructions">
            <Button variant="ghost"
              p="30px 20px"
              ms="40px"
              me="10px"
              sx={{
                color: 'black', // Default text color
                _hover: {
                  bg: 'rgba(0, 128, 0, 0.2)',  // Background color on hover
                },
              }}>
              Instructions
            </Button>
          </Link>
          <Link to="/upload">
            <Button
              variant="ghost"
              p="30px 20px"
              m="10px"
              sx={{
                color: 'black', // Default text color
                _hover: {
                  bg: 'rgba(0, 128, 0, 0.2)',  // Background color on hover
                },
              }}
            >
              Upload
            </Button>
          </Link>
          <Link to="/viewSavedPlans">
            <Button
              variant="ghost"
              p="30px 20px"
              m="10px"
              sx={{
                color: 'black', // Default text color
                _hover: {
                  bg: 'rgba(0, 128, 0, 0.2)',  // Background color on hover
                },
              }}
            >
              Saved Plans
            </Button>
          </Link>
        </HStack>

        {/* Wallet and Logout Buttons */}
        <HStack flex={1} spacing={4} justifyContent={"end"}>
          <ConnectWalletButton />
          {isAuthenticated && (
            <Button
              colorScheme="green"
              onClick={onLogout}
            >
              Logout
            </Button>
          )}
        </HStack>
      </Container>
    </Box>
  );
};
