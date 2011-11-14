#ifndef __UniformGrid_cuh__
#define __UniformGrid_cuh__

#ifdef USE_B40C_SORT
#include <b40c/radix_sort/enactor.cuh>
#include <b40c/util/ping_pong_storage.cuh>
using namespace b40c;
#endif

#include "SimCudaAllocator.h"
#include "SimCudaHelper.h"

#ifdef USE_CUDPP
#include "cudpp/cudpp.h"
#endif

#ifdef USE_THRUST_SORT
#include <thrust/device_vector.h>
#include <thrust/sort.h>
#include <thrust/random.h>
#endif

#include "UniformGrid.cuh"
#include "K_Common.cuh"
#include "ParticleData.h"
#include "SimBufferManager.h"
#include "SimBufferCuda.h"
#include "timer.h"

typedef unsigned int uint;

enum UniformGridBuffers
{
	SortHashes,
	SortIndexes,
	CellIndexesStart,
	CellIndexesStop,
};

struct NeighborList
{
	int numParticles;
	int MAX_NEIGHBORS;
	uint* neighbors;
	// pitch, IN ELEMENTS, NOT BYTES
	size_t		neighbors_pitch;
};

struct GridParams
{
	float3			grid_size;
	float3			grid_min;
	float3			grid_max;

	// number of cells in each dimension/side of grid
	float3			grid_res;

	float3			grid_delta;
};

struct GridData
{
	uint* sort_hashes;			// particle hashes
	uint* sort_indexes;			// particle indices
	uint* cell_indexes_start;	// mapping between bucket hash and start index in sorted list
	uint* cell_indexes_end;		// mapping between bucket hash and end index in sorted list
};


class UniformGrid
{
public:
	UniformGrid(SimLib::SimCudaAllocator* SimCudaAllocator,	SimLib::SimCudaHelper *simCudaHelper);
	~UniformGrid();

	void Alloc(uint numParticles, float cellWorldSize, float gridWorldSize);
	void Clear();
	void Free()	;

	float Hash(bool doTiming, float_vec* dParticlePositions, uint numParticles);
	float Sort(bool doTiming);

	GridData GetGridData(){
		GridData gridData;
#ifdef USE_B40C_SORT
		// if using b40c the results of the sort "ping-pong" between two buffers
		// we select the "current" results using the pingpongstorage selector.
		gridData.sort_hashes = m_b40c_storage->d_keys[m_b40c_storage->selector];
		gridData.sort_indexes = m_b40c_storage->d_values[m_b40c_storage->selector];
#else
		gridData.sort_hashes = mGridParticleBuffers->Get(SortHashes)->GetPtr<uint>();
		gridData.sort_indexes = mGridParticleBuffers->Get(SortIndexes)->GetPtr<uint>();
#endif
		gridData.cell_indexes_start = mGridCellBuffers->Get(CellIndexesStart)->GetPtr<uint>();
		gridData.cell_indexes_end = mGridCellBuffers->Get(CellIndexesStop)->GetPtr<uint>();
		return gridData;
	}

	uint GetNumCells(){return mNumCells;}
	GridParams& GetGridParams(){return dGridParams;}

private:
	void CalculateGridParameters(float cellWorldSize, float gridWorldSize);

	SimLib::BufferManager<UniformGridBuffers> *mGridParticleBuffers;
	SimLib::BufferManager<UniformGridBuffers> *mGridCellBuffers;

	uint mNumParticles;
	uint mNumCells;

	bool mAlloced;

	ocu::GPUTimer *mGPUTimer;

	SimLib::SimCudaAllocator* mSimCudaAllocator;
	SimLib::SimCudaHelper	*mSimCudaHelper;

	GridParams dGridParams;

#ifdef USE_CUDPP
	CUDPPHandle m_sortHandle;
#endif

#ifdef USE_B40C_SORT
	util::PingPongStorage<unsigned int,unsigned int>* m_b40c_storage;	
	b40c::radix_sort::Enactor* m_b40c_sorting_enactor;
#endif

#ifdef USE_THRUST_SORT
	thrust::device_ptr<uint>* mThrustKeys;
	thrust::device_ptr<uint>* mThrustVals;
#endif
	int mSortBitsPrecision;
};

#endif