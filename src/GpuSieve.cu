#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
#include <vector>
#include <chrono>
#include <cuda_runtime.h>

const uint64_t MAX_STRIDE = 256000000;
int BLOCK_SIZE = 512;
bool* isPrimeListHost = nullptr;

std::vector<uint64_t> sieveCpuPrep(uint64_t maxNumber) {
    std::vector<bool> isPrimeList;
    std::vector<uint64_t> prepedPrimes;
    std::cout << "joooo" << std::endl;
    isPrimeList.assign(maxNumber, true);

    int sqrtMaxNumber =maxNumber;

    for (uint64_t i = 2; i < sqrtMaxNumber; i++)
    {
        if (isPrimeList[i]) {
            prepedPrimes.push_back(i);

            for (uint64_t j = 2; i * j < maxNumber; j++) {
                isPrimeList[i * j] = false;
            }
        }
    }
    std::cout << "there" << std::endl;
    for (uint64_t i = sqrtMaxNumber; i < maxNumber; i++)
    {
        if (isPrimeList[i]) {
            prepedPrimes.push_back(i);
        }
    }
    return prepedPrimes;
}


__global__ void gpuSieveKernel(uint64_t maxNumber, bool* isPrimeList, uint64_t* prepedPrimes, uint64_t sizeOfPrepedPrimes) {
    uint64_t threadIndex = blockIdx.x * blockDim.x + threadIdx.x; // index = range of 0 up to MAX_STRIDE
    uint64_t stride = blockDim.x * gridDim.x;

    for (uint64_t i = threadIndex; i <= maxNumber; i += stride) 
    {
        if (i < 2) continue;

        for (uint64_t j = 0; j < sizeOfPrepedPrimes; j++) 
        {
            uint64_t currentNumber = prepedPrimes[j] * i;
            if (currentNumber > maxNumber) break;

            isPrimeList[currentNumber] = false;
        }
    }
}

void gpuSieve(uint64_t maxNumber, std::vector<uint64_t> prepedPrimes) {
    
    bool* isPrimeListDevice = nullptr;
    uint64_t* prepedPrimesDevice = nullptr;

    isPrimeListHost = (bool*)malloc(maxNumber * sizeof(bool));
    cudaMalloc(&isPrimeListDevice, maxNumber * sizeof(bool));
    std::memset(isPrimeListHost, true, maxNumber * sizeof(bool));
    cudaMemcpy(isPrimeListDevice, isPrimeListHost, maxNumber * sizeof(bool), cudaMemcpyHostToDevice);

    uint64_t prepedPrimesSize = prepedPrimes.size();
    uint64_t* prepedPrimesHost = (uint64_t*)malloc(prepedPrimesSize * sizeof(uint64_t));
    memcpy(prepedPrimesHost, prepedPrimes.data(), prepedPrimesSize * sizeof(uint64_t));
    cudaMalloc(&prepedPrimesDevice, prepedPrimesSize * sizeof(uint64_t));
    cudaMemcpy(prepedPrimesDevice, prepedPrimesHost, prepedPrimesSize * sizeof(uint64_t), cudaMemcpyHostToDevice);

    uint64_t numberOfBlocks = (maxNumber + BLOCK_SIZE - 1) / BLOCK_SIZE;
    uint64_t stride = BLOCK_SIZE * numberOfBlocks;

    if (stride > MAX_STRIDE) {
        numberOfBlocks = MAX_STRIDE / BLOCK_SIZE;
    }
    std::cout << "tutaj" << std::endl;
    gpuSieveKernel<<<numberOfBlocks, BLOCK_SIZE >>> (maxNumber, isPrimeListDevice, prepedPrimesDevice, prepedPrimesSize);

    cudaDeviceSynchronize();
    cudaMemcpy(isPrimeListHost, isPrimeListDevice, maxNumber * sizeof(bool), cudaMemcpyDeviceToHost);

    free(prepedPrimesHost);
    cudaFree(isPrimeListDevice);
    cudaFree(prepedPrimesDevice);
}

void checkPrimescount(int target) {
    uint64_t primesCount = 0;
    for (uint64_t i = 2; i <= target; i++) {
        if (isPrimeListHost[i]) primesCount++;
    }

    std::cout << "Prime numbers: " << primesCount << std::endl;
}




int main() {
    uint64_t target = 1000000000;

    auto startTime = std::chrono::high_resolution_clock::now();

    std::vector<uint64_t> prepedPrimes = sieveCpuPrep(std::sqrt(target));
    gpuSieve(target, prepedPrimes);

    auto endTime = std::chrono::high_resolution_clock::now();

    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);

    std::cout << "Time taken by threads: "
        << duration.count() << " microseconds" << std::endl;

    checkPrimescount(target);
    return 0;
}
