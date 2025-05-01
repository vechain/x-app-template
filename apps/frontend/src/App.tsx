import { Box, ChakraProvider, Container, Flex, Icon, Tab, TabList, Tabs } from "@chakra-ui/react";
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Marketplace,
  Navbar,
  SubmissionModal,
} from "./components";
import { FaHome, FaStore } from "react-icons/fa";

import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { lightTheme } from "./theme";
import { useState } from "react";

function App() {
  const [tabIndex, setTabIndex] = useState(0);

  return (
    <ChakraProvider theme={lightTheme}>
      <DAppKitProvider
        usePersistence
        requireCertificate={false}
        genesis="test"
        nodeUrl="https://testnet.vechain.org/"
        logLevel={"DEBUG"}
      >
        <Flex flexDirection="column" height="100vh">
          <Navbar />
          <Flex flex={1} overflow="auto">
            <Container
              mt={{ base: 4, md: 10 }}
              maxW={"container.xl"}
              mb={{ base: 4, md: 10 }}
              display={"flex"}
              flex={1}
              alignItems={"center"}
              justifyContent={"flex-start"}
              flexDirection={"column"}
            >
              {tabIndex === 0 ? (
                <>
                  <InfoCard />
                  <Instructions />
                  <Dropzone />
                  <Footer />
                </>
              ) : (
                <Marketplace />
              )}
            </Container>
          </Flex>

          {/* Bottom Navigation */}
          <Box 
            borderTop="1px" 
            borderColor="gray.200"
            position="fixed"
            bottom={0}
            left={0}
            right={0}
            bg="white"
            zIndex={1000}
          >
            <Tabs 
              isFitted 
              variant="enclosed" 
              index={tabIndex} 
              onChange={setTabIndex}
              size="lg"
            >
              <TabList>
                <Tab 
                  _selected={{ 
                    color: "blue.500", 
                    borderColor: "blue.500",
                    borderWidth: "4px",
                  }}
                  display="flex"
                  flexDirection="column"
                  gap={1}
                  py={3}
                >
                  <Icon as={FaHome} boxSize={5} />
                  Home
                </Tab>
                <Tab 
                  _selected={{ 
                    color: "blue.500", 
                    borderColor: "blue.500",
                    borderWidth: "4px",
                  }}
                  display="flex"
                  flexDirection="column"
                  gap={1}
                  py={3}
                >
                  <Icon as={FaStore} boxSize={5} />
                  Marketplace
                </Tab>
              </TabList>
            </Tabs>
          </Box>

          {/* Add padding to the bottom of the main content to account for fixed navbar */}
          <Box pb="70px" />

          {/* MODALS  */}
          <SubmissionModal />
        </Flex>
      </DAppKitProvider>
    </ChakraProvider>
  );
}

export default App;
