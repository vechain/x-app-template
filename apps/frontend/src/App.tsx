import { Box, ChakraProvider, Container, Flex, Tab, TabList, Tabs } from "@chakra-ui/react";
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Marketplace,
  Navbar,
  SubmissionModal,
} from "./components";

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
          <Box borderTop="1px" borderColor="gray.200">
            <Tabs isFitted variant="enclosed" index={tabIndex} onChange={setTabIndex}>
              <TabList>
                <Tab>Home</Tab>
                <Tab>Marketplace</Tab>
              </TabList>
            </Tabs>
          </Box>

         

          {/* MODALS  */}
          <SubmissionModal />
        </Flex>
      </DAppKitProvider>
    </ChakraProvider>
  );
}

export default App;
