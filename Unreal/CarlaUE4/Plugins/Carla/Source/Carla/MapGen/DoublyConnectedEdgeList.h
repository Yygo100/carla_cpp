// Copyright (c) 2017 Computer Vision Center (CVC) at the Universitat Autonoma
// de Barcelona (UAB).
//
// 此代码的版权相关声明，表明其遵循MIT许可协议。可通过指定链接查看协议详情。
//
// This work is licensed under the terms of the MIT license.
// For a copy, see <https://opensource.org/licenses/MIT>.

#pragma once
// 确保头文件只被编译一次，避免重复包含导致的编译错误

#include "GraphTypes.h"
#include "Position.h"
#include "Util/ListView.h"
// 引入自定义的头文件，可能包含了与图结构相关的类型定义、位置相关的结构体定义以及列表视图相关的功能实现

#include <array>
#include <list>
// 引入标准库中的数组和链表容器，用于存储数据元素

namespace MapGen {
    /// 简单的双连通边链表结构。它只允许添加元素，不允许删除元素。
    class CARLA_API DoublyConnectedEdgeList : private NonCopyable {
    // =========================================================================
    // -- DCEL 类型 -----------------------------------------------------------
    // =========================================================================
    public:

        using Position = MapGen::Position<int32>;
        // 为位置类型（Position）进行类型别名定义，方便使用，这里的Position具体是基于int32类型的某种位置表示

        struct Node;
        struct HalfEdge;
        struct Face;
        // 前置声明结构体，因为它们之间存在相互引用关系，先声明后再完整定义

        struct Node : public GraphNode {
            friend DoublyConnectedEdgeList;
            // 将DoublyConnectedEdgeList类声明为友元，使其可以访问Node的私有成员

            Node(const Position &Pos) : Position(Pos) {}
            // 构造函数，使用传入的位置信息初始化节点的位置属性

            Node &operator=(const Node &) = delete;
            // 禁止节点对象之间的赋值操作，防止意外赋值导致的错误

            const DoublyConnectedEdgeList::Position &GetPosition() const {
                return Position;
            }
            // 获取节点的位置信息

        private:
            DoublyConnectedEdgeList::Position Position;
            // 节点的位置属性，用于记录节点在空间中的位置
            HalfEdge *LeavingHalfEdge = nullptr;
            // 指向从此节点出发的半边（HalfEdge）的指针，初始化为nullptr
        };

        struct HalfEdge : public GraphHalfEdge {
            friend DoublyConnectedEdgeList;
            // 将DoublyConnectedEdgeList类声明为友元，使其可以访问HalfEdge的私有成员

            HalfEdge &operator=(const HalfEdge &) = delete;
            // 禁止半边对象之间的赋值操作

        private:
            Node *Source = nullptr;
            // 指向半边的源节点的指针，初始化为nullptr
            Node *Target = nullptr;
            // 指向半边的目标节点的指针，初始化为nullptr
            HalfEdge *Next = nullptr;
            // 指向在同一面内下一条半边的指针，初始化为nullptr
            HalfEdge *Pair = nullptr;
            // 指向与之配对的半边的指针（在双连通边链表中，每条半边都有对应的配对半边），初始化为nullptr
            Face *Face = nullptr;
            // 指向此半边所属面（Face）的指针，初始化为nullptr
        };

        struct Face : public GraphFace {
            friend DoublyConnectedEdgeList;
            // 将DoublyConnectedEdgeList类声明为友元，使其可以访问Face的私有成员

            Face &operator=(const Face &) = delete;
            // 禁止面对象之间的赋值操作

        private:
            HalfEdge *HalfEdge = nullptr;
            // 指向属于此面的一条半边的指针，通过它可以遍历此面包含的所有半边，初始化为nullptr
        };

        using NodeContainer = std::list<Node>;
        // 定义节点容器类型，使用标准库的链表来存储节点对象
        using NodeIterator = typename NodeContainer::iterator;
        // 定义节点容器的迭代器类型，用于遍历节点容器
        using ConstNodeIterator = typename NodeContainer::const_iterator;
        // 定义节点容器的常量迭代器类型，用于在不修改节点的情况下遍历节点容器

        using HalfEdgeContainer = std::list<HalfEdge>;
        // 定义半边容器类型，使用链表存储半边对象
        using HalfEdgeIterator = typename HalfEdgeContainer::iterator;
        // 定义半边容器的迭代器类型，用于遍历半边容器
        using ConstHalfEdgeIterator = typename HalfEdgeContainer::const_iterator;
        // 定义半边容器的常量迭代器类型，用于在不修改半边的情况下遍历半边容器

        using FaceContainer = std::list<Face>;
        // 定义面容器类型，使用链表存储面对象
        using FaceIterator = typename FaceContainer::iterator;
        // 定义面容器的迭代器类型，用于遍历面容器
        using ConstFaceIterator = typename FaceContainer::const_iterator;
        // 定义面容器的常量迭代器类型，用于在不修改面的情况下遍历面容器

    // =========================================================================
    // -- 构造函数和析构函数 ----------------------------------------------------
    // =========================================================================
    public:

        /// 创建一个有2个节点、2个边和1个面的双连通边链表DoublyConnectedEdgeList。
        explicit DoublyConnectedEdgeList(const Position &Position0, const Position &Position1);
        // 显式构造函数，根据传入的两个位置信息创建一个简单的双连通边链表结构，初始化两个节点、两条半边以及一个面（具体实现应该在对应的源文件中）

        /// 创建一个由N个节点组成双连通链表DoublyConnectedEdgeList环。
        template <size_t N>
        explicit DoublyConnectedEdgeList(const std::array<Position, N> &Cycle)
                : DoublyConnectedEdgeList(Cycle[0u], Cycle[1u]) {
            static_assert(N > 2u, "Not enough nodes to make a cycle!");
            // 静态断言，确保传入的节点数组大小足够组成一个环，即节点数量要大于2
            for (auto i = 2u; i < Cycle.size(); ++i) {
                AddNode(Cycle[i], Nodes.back());
            }
            // 循环调用AddNode函数，将节点逐个添加到链表结构中，以构建环，每次添加时关联到上一个添加的节点（Nodes.back()获取已添加的最后一个节点）
            ConnectNodes(Nodes.front(), Nodes.back());
            // 连接第一个节点和最后一个节点，完成环的构建
        }

        ~DoublyConnectedEdgeList();
        // 析构函数，用于释放双连通边链表结构占用的资源（具体释放哪些资源取决于类中成员变量的动态分配情况，实现应该在源文件中）

    // =========================================================================
    /// @name 向图中添加元素-----------------------------------------------------
    // =========================================================================
    /// {
    public:

        /// Add a node at @a NodePosition and attach it to @a OtherNode.
        /// 在指定的位置 @a NodePosition 添加一个节点，并将其连接到 @a OtherNode 节点上。
        ///
        /// 时间复杂度为 O(n*log(n))，其中 n 是离开节点 @a OtherNode 的边数。
        /// 说明此操作在有较多离开 @a OtherNode 的边时，时间开销与边数及对数边数相关。
        ///
        /// @return 新生成的节点。
        Node &AddNode(const Position &NodePosition, Node &OtherNode);
        // 添加节点的函数声明，传入要添加节点的位置以及关联的已有节点，返回新添加的节点引用（具体实现应该在源文件中）

        /// 在 @a 位置分割 @a HalfEdge （和它的配对）
        ///
        /// 时间复杂度为 O(n*log(n))，其中 n 是离开 @a HalfEdge 源的边数
        /// 表明分割操作的时间开销与半边源节点的边数及对数边数相关。
        ///
        /// @return 新生成的节点。
        Node &SplitEdge(const Position &Position, HalfEdge &HalfEdge);
        // 分割半边的函数声明，传入分割的位置以及要分割的半边，返回分割后新生成的节点引用（具体实现应该在源文件中）

        /// 用一对边连接两个节点。
        ///
        /// 假设两个节点由同一面连接。
        /// 说明此操作的前提假设，即两个节点需要在同一个面内才能进行连接操作。
        ///
        /// 时间复杂度为 O(n0*log(n0) + n1*log(n1) + nf)，
        /// 其中 n0 和 n1 分别是离开节点 @a Node0 和节点 @a Node1 的边数。
        /// 并且 nf 是包含两个节点的面的边数。
        /// 解释了连接操作的时间复杂度与两个节点各自的出边数量以及它们所在面的边数相关。
        ///
        /// @return 新生成的面。
        Face &ConnectNodes(Node &Node0, Node &Node1);
        // 连接两个节点的函数声明，传入要连接的两个节点，返回连接后新生成的面的引用（具体实现应该在源文件中）

        /// @}
    // =========================================================================
    /// @name 统计图元素的数目 --------------------------------------------------
    // =========================================================================
    /// @{
    public:

        size_t CountNodes() const {
            return Nodes.size();
        }
        // 返回节点容器中节点的数量，通过调用节点容器的size()函数实现

        size_t CountHalfEdges() const {
            return HalfEdges.size();
        }
        // 返回半边容器中半边的数量，通过调用半边容器的size()函数实现

        size_t CountFaces() const {
            return Faces.size();
        }
        // 返回面容器中面的数量，通过调用面容器的size()函数实现

        /// @}
    // =========================================================================
    /// @name 访问图的元素 ------------------------------------------------------
    // =========================================================================
    /// @{
    public:

        ListView<NodeIterator> GetNodes() {
            return ListView<NodeIterator>(Nodes);
        }
        // 获取节点容器的视图（ListView可能是自定义的一种方便访问容器元素的类型），返回可以遍历节点的迭代器视图

        ListView<ConstNodeIterator> GetNodes() const {
            return ListView<ConstNodeIterator>(Nodes);
        }
        // 获取节点容器的常量视图，用于在不修改节点的情况下遍历节点，返回常量迭代器视图

        ListView<HalfEdgeIterator> GetHalfEdges() {
            return ListView<HalfEdgeIterator>(HalfEdges);
        }
        // 获取半边容器的视图，返回可以遍历半边的迭代器视图

        ListView<ConstHalfEdgeIterator> GetHalfEdges() const {
            return ListView<ConstHalfEdgeIterator>(HalfEdges);
        }
        // 获取半边容器的常量视图，用于在不修改半边的情况下遍历半边，返回常量迭代器视图

        ListView<FaceIterator> GetFaces() {
            return ListView<FaceIterator>(Faces);
        }
        // 获取面容器的视图，返回可以遍历面的迭代器视图

        ListView<ConstFaceIterator> GetFaces() const {
            return ListView<ConstFaceIterator>(Faces);
        }
        // 获取面容器的常量视图，用于在不修改面的情况下遍历面，返回常量迭代器视图

        /// @}
    // =========================================================================
    /// @name 访问图指针 --------------------------------------------------------
    // =========================================================================
    /// @{
    public:

        // -- 主要指针 --------------------------------------------------------------

        static Node &GetSource(HalfEdge &halfEdge) {
            check(halfEdge.Source!= nullptr);
            return *halfEdge.Source;
        }
        // 获取半边的源节点的引用，先检查源节点指针是否为空（通过check函数，具体实现应该在别处定义），然后返回源节点的引用

        static const Node &GetSource(const HalfEdge &halfEdge) {
            check(halfEdge.Source!= nullptr);
            return *halfEdge.Source;
        }
        // 获取半边的源节点的常量引用，同样先检查指针是否为空，然后返回常量引用，用于在不修改源节点的情况下获取其信息

        static Node &GetTarget(HalfEdge &halfEdge) {
            check(halfEdge.Target!= nullptr);
            return *halfEdge.Target;
        }
        // 获取半边的目标节点的引用，检查目标节点指针不为空后返回其引用

        static const Node &GetTarget(const HalfEdge &halfEdge) {
            check(halfEdge.Target!= nullptr);
            return *halfEdge.Target;
        }
        // 获取半边的目标节点的常量引用，用于不修改目标节点的情况下获取其信息

        static HalfEdge &GetPair(HalfEdge &halfEdge) {
            check(halfEdge.Pair!= nullptr);
            return *halfEdge.Pair;
        }
        // 获取半边的配对半边的引用，检查配对半边指针不为空后返回其引用

        static const HalfEdge &GetPair(const HalfEdge &halfEdge) {
            check(halfEdge.Pair!= nullptr);
            return *halfEdge.Pair;
        }
        // 获取半边的配对半边的常量引用，用于不修改配对半边的情况下获取其信息

        static Face &GetFace(HalfEdge &halfEdge) {
            check(halfEdge.Face!= nullptr);
            return *halfEdge.Face;
        }
        // 获取半边所属面的引用，检查面指针不为空后返回其引用

        static const Face &GetFace(const HalfEdge &halfEdge) {
            check(halfEdge.Face!= nullptr);
            return *halfEdge.Face;
        }
        // 获取半边所属面的常量引用，用于不修改面的情况下获取其信息

        static HalfEdge &GetLeavingHalfEdge(Node &node) {
            check(node.LeavingHalfEdge!= nullptr);
            return *node.LeavingHalfEdge;
        }
        // 获取节点出发的半边的引用，检查出发半边指针不为空后返回其引用

        static const HalfEdge &GetLeavingHalfEdge(const Node &node) {
            check(node.LeavingHalfEdge!= nullptr);
            return *node.LeavingHalfEdge;
        }
        // 获取节点出发的半边的常量引用，用于不修改出发半边的情况下获取其信息

        static HalfEdge &GetHalfEdge(Face &face) {
            check(face.HalfEdge!= nullptr);
            return *face.HalfEdge;
        }
        // 获取面的一条半边的引用，检查半边指针不为空后返回其引用

        static const HalfEdge &GetHalfEdge(const Face &face) {
            check(face.HalfEdge!= nullptr);
            return *face.HalfEdge;
        }
        // 获取面的一条半边的常量引用，用于不修改半边的情况下获取其信息

        // -- 二级指针 ------------------------------------------------------------

        static HalfEdge &GetNextInFace(HalfEdge &halfEdge) {
            check(halfEdge.Next!= nullptr);
            return *halfEdge.Next;
        }
        // 获取在同一面内下一条半边的引用，检查下一条半边指针不为空后返回其引用

        static const HalfEdge &GetNextInFace(const HalfEdge &halfEdge) {
            check(halfEdge.Next!= nullptr);
            return *halfEdge.Next;
        }
        // 获取在同一面内下一条半边的常量引用，用于不修改下一条半边的情况下获取其信息

        static HalfEdge &GetNextInNode(HalfEdge &halfEdge) {
            return GetNextInFace(GetPair(halfEdge));
        }
        // 获取在节点的下一条半边（通过先获取配对半边，再获取配对半边所在面的下一条半边来实现）的引用

        static const HalfEdge &GetNextInNode(const HalfEdge &halfEdge) {
            return GetNextInFace(GetPair(halfEdge));
        }
        // 获取在节点的下一条半边的常量引用，用于不修改下一条半边的情况下获取其信息

        /// @}
    // =========================================================================
    /// @name 其他成员函数 ------------------------------------------------------
    // =========================================================================
    /// @{
    public:

        /// 返回 half-edge 的角度，范围为 [-pi, pi]
        static float GetAngle(const HalfEdge &halfEdge);
        // 获取半边的角度的静态函数声明，返回值是角度值，范围限定在 [-π, π] 之间（具体计算角度的实现应该在源文件中）

#ifdef CARLA_ROAD_GENERATOR_EXTRA_LOG
        void PrintToLog() const;
        // 如果定义了CARLA_ROAD_GENERATOR_EXTRA_LOG宏，此函数用于将双连通边链表的相关信息输出到日志中（具体输出哪些信息的实现应该在源文件中）
#endif // CARLA_ROAD_GENERATOR_EXTRA_LOG

        /// @}
    // =========================================================================
    // -- 私有成员 --------------------------------------------------------------
    // =========================================================================

    private:

        NodeContainer Nodes;
        // 存储节点的容器，使用链表来保存所有节点对象

        HalfEdgeContainer HalfEdges;
        // 存储半边的容器，用链表保存所有半边对象

        FaceContainer Faces;
        // 存储面的容器，通过链表来存放所有面对象
    };

} // namespace MapGen
