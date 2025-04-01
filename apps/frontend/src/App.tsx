import {ChakraProvider, Container, Flex} from "@chakra-ui/react";
import {Dropzone, Footer, InfoCard, Instructions, Navbar, SubmissionModal} from "./components";
import {lightTheme} from "./theme";
import {VeChainKitProviderWrapper} from "./providers";

function App() {
  return (
    <ChakraProvider theme={lightTheme}>
      <VeChainKitProviderWrapper>
        <Navbar />
        <Flex flex={1}>
          <Container mt={{base: 4, md: 10}} maxW={"container.xl"} mb={{base: 4, md: 10}} display={"flex"} flex={1} alignItems={"center"} justifyContent={"flex-start"} flexDirection={"column"}>
            <InfoCard />
            <Instructions />
            <Dropzone />
          </Container>
        </Flex>
        <Footer />

        {/* MODALS  */}
        <SubmissionModal />
      </VeChainKitProviderWrapper>
    </ChakraProvider>
  );
}

export default App;
